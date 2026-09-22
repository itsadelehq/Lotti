import Foundation

enum DeepgramParser {
    private struct Frame: Decodable {
        struct Channel: Decodable { struct Alt: Decodable { let transcript: String }
            let alternatives: [Alt] }
        let is_final: Bool?
        let channel: Channel?
        let type: String?
    }
    static func transcript(from json: Data) -> (text: String, isFinal: Bool)? {
        guard let f = try? JSONDecoder().decode(Frame.self, from: json),
              let text = f.channel?.alternatives.first?.transcript,
              !text.isEmpty else { return nil }
        return (text, f.is_final ?? false)
    }
    /// True when the message signals that the post-`Finalize` flush is complete:
    /// Deepgram emits a `{"type":"Metadata"}` frame (and closes the turn) once it
    /// has delivered the remaining final results for the flushed tail audio.
    static func isFinalizeComplete(from json: Data) -> Bool {
        guard let f = try? JSONDecoder().decode(Frame.self, from: json) else { return false }
        return f.type == "Metadata"
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

    // --- Tail capture (finalize) state, all confined to `queue`. ---
    /// True between `finish()` sending Finalize and the trailing finals landing.
    private var isFinishing = false
    /// Resumed exactly once when the finalize flush is judged complete.
    private var finishContinuation: CheckedContinuation<Void, Never>?
    /// Fires ~250ms after the last trailing final; declares the flush quiet.
    private var quietTimer: DispatchWorkItem?
    /// Hard upper bound (~1.5s) so `finish()` always returns.
    private var hardCapTimer: DispatchWorkItem?
    /// Set true when Finalize completed normally, so the subsequent socket close
    /// is recognised as expected and not logged/toasted as an error.
    private var finalizeCompleted = false

    private let quietWindow: TimeInterval = 0.25
    private let hardCap: TimeInterval = 1.5

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
                    if case .string(let s) = msg, let d = s.data(using: .utf8) {
                        if let parsed = DeepgramParser.transcript(from: d) {
                            if parsed.isFinal {
                                AppLog.log("Deepgram: FINAL transcript — \"\(parsed.text)\"")
                            }
                            self.onTranscriptHandler?(parsed.text, parsed.isFinal)
                            // While flushing the tail, every trailing final restarts
                            // a short quiet timer; when it elapses the flush is done.
                            if self.isFinishing && parsed.isFinal {
                                self.armQuietTimer()
                            }
                        } else if self.isFinishing, DeepgramParser.isFinalizeComplete(from: d) {
                            // Deepgram acknowledged the flush — resolve immediately.
                            self.resolveFinish()
                        }
                    }
                case .failure(let error):
                    // A normal post-finalize/close cancels the socket and surfaces
                    // here too; don't log a scary error for the expected case.
                    if self.userClosed || self.finalizeCompleted {
                        // If we were still waiting on the flush, unblock finish().
                        if self.isFinishing { self.resolveFinish() }
                        break
                    }
                    AppLog.log("Deepgram: websocket error/closed — \(error.localizedDescription)")
                    if self.isFinishing { self.resolveFinish() }
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

    /// Flush Deepgram and WAIT (bounded) for the trailing final transcript(s) that
    /// arrive a few hundred ms after `Finalize`, delivering them through
    /// `onTranscript` before returning. Only then is the socket closed. This is
    /// what prevents the END of longer/faster speech ("tail") from being dropped.
    func finish() async {
        finalize() // sends {"type":"Finalize"}
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                // Guard against a socket that already failed/closed before we got here.
                guard self.task != nil, !self.userClosed else {
                    cont.resume()
                    return
                }
                self.isFinishing = true
                self.finishContinuation = cont
                // Ultimate upper bound so finish() always returns even if Deepgram
                // never acknowledges (e.g. dropped connection).
                self.armHardCap()
            }
        }
        // The trailing finals (if any) have now been delivered — close the socket.
        finalizeCompleted = true
        close()
        AppLog.log("[Lotti] Deepgram: finalize complete, socket closed")
    }

    /// (Re)arm the quiet timer: when no new final arrives for `quietWindow`, the
    /// flush is considered drained. Must be called on `queue`.
    private func armQuietTimer() {
        quietTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.resolveFinish() }
        quietTimer = work
        queue.asyncAfter(deadline: .now() + quietWindow, execute: work)
    }

    /// Arm the hard-cap timer. Must be called on `queue`.
    private func armHardCap() {
        hardCapTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.resolveFinish() }
        hardCapTimer = work
        queue.asyncAfter(deadline: .now() + hardCap, execute: work)
    }

    /// Resume `finish()` exactly once and stop all finalize timers. Must be
    /// called on `queue`.
    private func resolveFinish() {
        guard isFinishing else { return }
        isFinishing = false
        quietTimer?.cancel(); quietTimer = nil
        hardCapTimer?.cancel(); hardCapTimer = nil
        let cont = finishContinuation
        finishContinuation = nil
        cont?.resume()
    }
}
