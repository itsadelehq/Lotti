// Core/AudioCapture.swift
import AVFoundation

final class AudioCapture {
    var onPCM: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

    func start() throws {
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: targetFormat)
        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buf, _ in
            self?.process(buf)
        }
        engine.prepare()
        try engine.start()
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
    }
}
