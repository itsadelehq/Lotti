import XCTest
@testable import Lotti

final class FakeEngine: TranscriptionEngine {
    var onTranscript: ((String, Bool) -> Void)?
    func start() async throws {}
    func send(_ pcm: Data) {}
    func finish() async {}
    func emit(_ t: String, final: Bool) { onTranscript?(t, final) }
}

@MainActor
final class CoordinatorTests: XCTestCase {
    func test_accumulatesFinalsAndSaves() async {
        let store = Store(inMemory: true)
        let fake = FakeEngine()
        let coord = DictationCoordinator(store: store,
            makeEngine: { fake }, makePolish: { nil }, inject: false)
        coord.begin()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.emit("hello", final: true)
        fake.emit("world", final: true)
        await coord.end(cancelled: false)
        XCTAssertEqual(store.all().first?.rawText, "hello world")
    }
    func test_cancel_savesNothing() async {
        let store = Store(inMemory: true)
        let fake = FakeEngine()
        let coord = DictationCoordinator(store: store,
            makeEngine: { fake }, makePolish: { nil }, inject: false)
        coord.begin()
        fake.emit("discard me", final: true)
        await coord.end(cancelled: true)
        XCTAssertTrue(store.all().isEmpty)
    }
}
