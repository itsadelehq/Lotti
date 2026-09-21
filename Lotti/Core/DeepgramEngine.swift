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
    // All access to `task` and `onTranscriptHandler` is confined to `queue`,
    // a serial DispatchQueue, so they are never read/written concurrently even
    // though URLSession invokes the `receive()` completion on an arbitrary
    // queue. `@unchecked Sendable` is retained only because URLSessionWebSocketTask
    // itself requires the enclosing type to cross isolation boundaries; the
    // queue below is the real synchronization that makes that safe.
    private let queue = DispatchQueue(label: "lotti.deepgram")
    private var task: URLSessionWebSocketTask?
    private var onTranscriptHandler: ((String, Bool) -> Void)?
    private let apiKey: String
    private let keywords: [String]
    /// Set once close()/finish() runs so a subsequent WS failure is recognised as
    /// a user-initiated stop and does NOT surface an error toast.
    private var userClosed = false

    var onTranscript: ((String, Bool) -> Void)? {
        get { queue.sync { onTranscriptHandler } }
        set { queue.sync { onTranscriptHandler = newValue } }
    }

    init(apiKey: String, keywords: [String] = []) {
        self.apiKey = apiKey
        self.keywords = keywords
    }

    func start() async throws {
        var comps = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        comps.queryItems = [
            .init(name: "model", value: "nova-2"),
            .init(name: "encoding", value: "linear16"),
            .init(name: "sample_rate", value: "16000"),
            .init(name: "interim_results", value: "true"),
            .init(name: "language", value: "en"),
            // Smart formatting + punctuation make the RAW transcript already
            // well-punctuated and capitalised, so Haiku only lightly corrects
            // (better accuracy, less work). Endpointing finalizes utterances fast.
            .init(name: "smart_format", value: "true"),
            .init(name: "punctuate", value: "true"),
            .init(name: "endpointing", value: "true"),
        ]
        // Custom vocabulary → Deepgram keyword boosting. Each term is boosted
        // with the `:2` intensifier; URLComponents percent-encodes the term
        // (spaces in multi-word phrases are preserved as %20).
        let cleanedKeywords = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        comps.queryItems?.append(contentsOf: cleanedKeywords.map {
            URLQueryItem(name: "keywords", value: "\($0):2")
        })
        AppLog.log("[Lotti] deepgram: \(cleanedKeywords.count) keyword(s) applied")
        var req = URLRequest(url: comps.url!)
        req.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        let newTask = URLSession.shared.webSocketTask(with: req)
        queue.sync { task = newTask }
        newTask.resume()
        AppLog.log("Deepgram: websocket opened (model=nova-2, 16k linear16, smart_format+punctuate+endpointing)")
        receive()
    }
    private func receive() {
        let currentTask = queue.sync { task }
        currentTask?.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                switch result {
                case .success(let msg):
                    if case .string(let s) = msg, let d = s.data(using: .utf8),
                       let parsed = DeepgramParser.transcript(from: d) {
                        if parsed.isFinal {
                            AppLog.log("Deepgram: FINAL transcript — \"\(parsed.text)\"")
                        }
                        self.onTranscriptHandler?(parsed.text, parsed.isFinal)
                    }
                case .failure(let error):
                    AppLog.log("Deepgram: websocket error/closed — \(error.localizedDescription)")
                    // Only toast when this was NOT a user-initiated stop; a normal
                    // close cancels the socket and surfaces as a failure here too.
                    if !self.userClosed {
                        let ns = error as NSError
                        // A 401/handshake rejection surfaces as a specific URLError.
                        if ns.domain == NSURLErrorDomain,
                           ns.code == NSURLErrorUserAuthenticationRequired
                            || ns.code == NSURLErrorUserCancelledAuthentication {
                            Toaster.shared.error("Your Deepgram key looks invalid — check Settings → Keys.")
                        } else {
                            Toaster.shared.error("Couldn't reach Deepgram — check your key and connection.")
                        }
                    }
                }
            }
            if case .success = result {
                self.receive()
            }
        }
    }
    func send(_ pcm: Data) {
        queue.sync { task }?.send(.data(pcm)) { _ in }
    }
    /// Flush buffered audio so Deepgram emits any pending final transcript
    /// immediately, WITHOUT closing the socket. Non-blocking.
    func finalize() {
        queue.sync { task }?.send(.string(#"{"type":"Finalize"}"#)) { _ in }
        AppLog.log("Deepgram: sent Finalize (flush)")
    }
    /// Tear down the socket in the background — nothing awaits this on the
    /// paste path, so the WS close handshake never adds to perceived latency.
    func close() {
        let currentTask = queue.sync { task }
        queue.async { self.userClosed = true; self.task = nil }
        currentTask?.send(.string(#"{"type":"CloseStream"}"#)) { _ in }
        currentTask?.cancel(with: .goingAway, reason: nil)
        AppLog.log("Deepgram: websocket closed (background)")
    }
    func finish() async { close() }
}
