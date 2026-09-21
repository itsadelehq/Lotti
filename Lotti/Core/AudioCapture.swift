// Core/AudioCapture.swift
import AVFoundation

final class AudioCapture {
    var onPCM: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var didLogFirstBuffer = false
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

    func start() throws {
        // Surface a denied/undetermined mic so it doesn't silently fail.
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status != .authorized {
            AppLog.log("AudioCapture: microphone NOT authorized (status=\(status.rawValue)) — capture will produce no audio. Grant it in Settings → Permissions / System Settings → Privacy → Microphone.")
            Toaster.shared.error("Microphone access is off — enable it in System Settings → Privacy.")
        }
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: targetFormat)
        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buf, _ in
            self?.process(buf)
        }
        engine.prepare()
        do {
            try engine.start()
            AppLog.log("AudioCapture: engine started (input \(Int(inFormat.sampleRate))Hz → 16k PCM)")
        } catch {
            AppLog.log("AudioCapture: engine.start() FAILED — \(error.localizedDescription)")
            throw error
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
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        didLogFirstBuffer = false
    }
}
