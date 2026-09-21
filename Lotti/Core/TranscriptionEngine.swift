import Foundation

protocol TranscriptionEngine: AnyObject {
    var onTranscript: ((String, Bool) -> Void)? { get set }
    func start() async throws
    func send(_ pcm: Data)
    func finish() async
    /// Flush any buffered audio so the provider emits its final transcript(s)
    /// promptly, WITHOUT tearing down the connection. Returns immediately; the
    /// last final transcript(s) arrive via `onTranscript` shortly after.
    func finalize()
    /// Tear down the connection in the background. Must not block the caller.
    func close()
}

extension TranscriptionEngine {
    // Default no-ops so lightweight/test engines conform without extra code.
    func finalize() {}
    func close() {}
}
