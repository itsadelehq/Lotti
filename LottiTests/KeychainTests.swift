import XCTest
@testable import Lotti

final class KeychainTests: XCTestCase {
    let key = "test_key_\(UUID().uuidString)"
    override func tearDown() { Keychain.delete(key) }

    func test_setThenGet_returnsValue() throws {
        try Keychain.set("secret123", for: key)
        XCTAssertEqual(Keychain.get(key), "secret123")
    }
    func test_overwrite_updatesValue() throws {
        try Keychain.set("a", for: key)
        try Keychain.set("b", for: key)
        XCTAssertEqual(Keychain.get(key), "b")
    }
    func test_delete_removesValue() throws {
        try Keychain.set("x", for: key)
        Keychain.delete(key)
        XCTAssertNil(Keychain.get(key))
    }
    func test_getMissing_returnsNil() {
        XCTAssertNil(Keychain.get("never_set_\(UUID().uuidString)"))
    }
}
