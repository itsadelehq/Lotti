import XCTest
@testable import Lotti

final class HotkeyStateTests: XCTestCase {
    func machine() -> HotkeyStateMachine { let m = HotkeyStateMachine(); m.triggerKey = 0x36; return m } // right-cmd

    func test_holdAndRelease_startsThenStops() {
        let m = machine()
        XCTAssertEqual(m.handle(keyCode: 0x36, isDown: true, spaceDown: false), .start)
        XCTAssertEqual(m.handle(keyCode: 0x36, isDown: false, spaceDown: false), .stop)
    }
    func test_triggerPlusSpace_locks_soReleaseDoesNotStop() {
        let m = machine()
        _ = m.handle(keyCode: 0x36, isDown: true, spaceDown: false)   // start
        XCTAssertEqual(m.handle(keyCode: 0x31, isDown: true, spaceDown: true), .lockToggle) // space while holding
        XCTAssertNil(m.handle(keyCode: 0x36, isDown: false, spaceDown: false)) // release ignored (locked)
    }
    func test_lockedThenTriggerAgain_stops() {
        let m = machine()
        _ = m.handle(keyCode: 0x36, isDown: true, spaceDown: false)
        _ = m.handle(keyCode: 0x31, isDown: true, spaceDown: true)    // lock
        _ = m.handle(keyCode: 0x36, isDown: false, spaceDown: false)  // ignored
        XCTAssertEqual(m.handle(keyCode: 0x36, isDown: true, spaceDown: false), .stop) // press again stops
    }
    func test_unrelatedKey_isIgnored() {
        let m = machine()
        XCTAssertNil(m.handle(keyCode: 0x00, isDown: true, spaceDown: false))
    }
}
