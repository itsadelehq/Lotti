// Core/AudioCapture.swift
import AVFoundation
import CoreAudio

/// Enumerates input audio devices and resolves stored selections. Backed by
/// CoreAudio's hardware object graph. All `AudioObjectGetPropertyData` calls are
/// guarded and never crash if a device disappears mid-query.
enum AudioDevices {
    /// All input-capable devices as (persistent UID, human-readable name).
    static func inputs() -> [(id: String, name: String)] {
        var result: [(id: String, name: String)] = []
        for deviceID in allDeviceIDs() where hasInputStreams(deviceID) {
            guard let uid = stringProperty(deviceID, kAudioDevicePropertyDeviceUID),
                  let name = stringProperty(deviceID, kAudioObjectPropertyName) else { continue }
            result.append((id: uid, name: name))
        }
        return result
    }

    /// The name of the current system default input device, or "System Default".
    static func systemDefaultName() -> String {
        guard let id = defaultInputDeviceID(),
              let name = stringProperty(id, kAudioObjectPropertyName) else {
            return "System Default"
        }
        return name
    }

    /// Resolves a stored UID to a live `AudioDeviceID`. nil if empty/not found.
    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        guard !uid.isEmpty else { return nil }
        for deviceID in allDeviceIDs() where hasInputStreams(deviceID) {
            if stringProperty(deviceID, kAudioDevicePropertyDeviceUID) == uid {
                return deviceID
            }
        }
        return nil
    }

    // MARK: - CoreAudio plumbing

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return [] }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids)
        guard status == noErr else { return [] }
        return ids
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else { return false }
        let bufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferList) == noErr
        else { return false }
        let listPtr = bufferList.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(listPtr)
        for buffer in buffers where buffer.mNumberChannels > 0 { return true }
        return false
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID)
        guard status == noErr, deviceID != 0 else { return nil }
        return deviceID
    }

    private static func stringProperty(_ deviceID: AudioDeviceID,
                                       _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        var cfName: CFString? = nil
        let status = withUnsafeMutablePointer(to: &cfName) { ptr -> OSStatus in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, ptr)
        }
        guard status == noErr, let name = cfName else { return nil }
        return name as String
    }
}

final class AudioCapture {
    var onPCM: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var didLogFirstBuffer = false
    private var isRunning = false
    private var configObserver: NSObjectProtocol?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

    func start() throws {
        // Surface a denied/undetermined mic so it doesn't silently fail.
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status != .authorized {
            AppLog.log("AudioCapture: microphone NOT authorized (status=\(status.rawValue)) — capture will produce no audio. Grant it in Settings → Permissions / System Settings → Privacy → Microphone.")
            Toaster.shared.error("Microphone access is off — enable it in System Settings → Privacy.")
        }

        // Select the user's chosen input device (if any) BEFORE querying the
        // input format or starting the engine. Empty/unknown UID = system default.
        applySelectedInputDevice()

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: targetFormat)
        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buf, _ in
            self?.process(buf)
        }
        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            let deviceName = currentInputDeviceName()
            AppLog.log("[Lotti] AudioCapture: input device = \"\(deviceName)\" (\(Int(inFormat.sampleRate))Hz)")
            AppLog.log("AudioCapture: engine started (input \(Int(inFormat.sampleRate))Hz → 16k PCM)")
        } catch {
            AppLog.log("AudioCapture: engine.start() FAILED — \(error.localizedDescription)")
            throw error
        }

        // Restart cleanly if a device appears/disappears mid-use so a config
        // change doesn't wedge the tap.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    /// Sets the chosen input device on the engine's input audio unit via
    /// CoreAudio. Falls back to the system default when UID is empty/not found.
    private func applySelectedInputDevice() {
        let uid = UserDefaults.standard.string(forKey: "inputDeviceUID") ?? ""
        guard let deviceID = AudioDevices.deviceID(forUID: uid) else {
            if !uid.isEmpty {
                AppLog.log("[Lotti] AudioCapture: stored input UID not found — using system default")
            }
            return
        }
        guard let audioUnit = engine.inputNode.audioUnit else {
            AppLog.log("[Lotti] AudioCapture: inputNode has no audioUnit — using system default")
            return
        }
        var dev = deviceID
        let err = AudioUnitSetProperty(
            audioUnit, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0, &dev, UInt32(MemoryLayout<AudioDeviceID>.size))
        if err != noErr {
            AppLog.log("[Lotti] AudioCapture: failed to set input device (err \(err)) — using system default")
        }
    }

    private func currentInputDeviceName() -> String {
        let uid = UserDefaults.standard.string(forKey: "inputDeviceUID") ?? ""
        if let match = AudioDevices.inputs().first(where: { $0.id == uid }) {
            return match.name
        }
        return AudioDevices.systemDefaultName()
    }

    private func handleConfigurationChange() {
        guard isRunning else { return }
        AppLog.log("[Lotti] AudioCapture: configuration changed — restarting tap")
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        didLogFirstBuffer = false

        applySelectedInputDevice()
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: targetFormat)
        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buf, _ in
            self?.process(buf)
        }
        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            AppLog.log("[Lotti] AudioCapture: input device = \"\(currentInputDeviceName())\" (\(Int(inFormat.sampleRate))Hz)")
        } catch {
            AppLog.log("AudioCapture: engine restart FAILED — \(error.localizedDescription)")
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let cap = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: cap) else { return }
        var err: NSError?
        var fed = false
        converter.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true; status.pointee = .haveData; return buffer
        }
        if let ch = out.int16ChannelData, out.frameLength > 0 {
            let data = Data(bytes: ch[0], count: Int(out.frameLength) * 2)
            if !didLogFirstBuffer {
                didLogFirstBuffer = true
                AppLog.log("AudioCapture: first PCM buffer delivered (\(data.count) bytes)")
            }
            onPCM?(data)
            // RMS level for waveform
            let n = Int(out.frameLength)
            var sum: Float = 0
            for i in 0..<n { let s = Float(ch[0][i]) / 32768; sum += s * s }
            onLevel?(min(1, sqrt(sum / Float(max(n,1))) * 4))
        }
    }
    func stop() {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        didLogFirstBuffer = false
    }
}
