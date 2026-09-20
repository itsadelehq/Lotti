import Foundation

enum DeepgramParser {
    private struct Frame: Decodable {
        struct Channel: Decodable { struct Alt: Decodable { let transcript: String }
            let alternatives: [Alt] }
        let is_final: Bool?
        let channel: Channel?
    }
    static func transcript(from json: Data) -> (text: String, isFinal: Bool)? {
        guard let f = try? JSONDecoder().decode(Frame.self, from: json),
              let text = f.channel?.alternatives.first?.transcript,
              !text.isEmpty else { return nil }
        return (text, f.is_final ?? false)
    }
}

final class DeepgramEngine: TranscriptionEngine, @unchecked Sendable {
    var onTranscript: ((String, Bool) -> Void)?
    private var task: URLSessionWebSocketTask?
    private let apiKey: String
    init(apiKey: String) { self.apiKey = apiKey }

    func start() async throws {
        var comps = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        comps.queryItems = [
            .init(name: "model", value: "nova-2"),
            .init(name: "encoding", value: "linear16"),
            .init(name: "sample_rate", value: "16000"),
            .init(name: "interim_results", value: "true"),
            .init(name: "language", value: "en"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        task = URLSession.shared.webSocketTask(with: req)
        task?.resume()
        receive()
    }
    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            if case .success(let msg) = result {
                if case .string(let s) = msg, let d = s.data(using: .utf8),
                   let parsed = DeepgramParser.transcript(from: d) {
                    self.onTranscript?(parsed.text, parsed.isFinal)
                }
                self.receive()
            }
        }
    }
    func send(_ pcm: Data) { task?.send(.data(pcm)) { _ in } }
    func finish() async {
        // Deepgram closes on a zero-length frame + CloseStream message
        task?.send(.string(#"{"type":"CloseStream"}"#)) { _ in }
        task?.cancel(with: .goingAway, reason: nil)
    }
}
