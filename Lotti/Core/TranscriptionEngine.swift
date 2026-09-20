import Foundation

protocol TranscriptionEngine: AnyObject {
    var onTranscript: ((String, Bool) -> Void)? { get set }
    func start() async throws
    func send(_ pcm: Data)
    func finish() async
}
