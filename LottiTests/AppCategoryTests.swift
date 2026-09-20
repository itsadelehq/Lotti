import XCTest
@testable import Lotti

final class AppCategoryTests: XCTestCase {
    func test_knownAI() {
        XCTAssertEqual(AppCategory.category(forBundleId: "com.openai.chat"), .aiTools)
        XCTAssertEqual(AppCategory.category(forBundleId: "com.anthropic.claude"), .aiTools)
    }
    func test_messaging() {
        XCTAssertEqual(AppCategory.category(forBundleId: "com.tinyspeck.slackmacgap"), .messaging)
    }
    func test_email() {
        XCTAssertEqual(AppCategory.category(forBundleId: "com.apple.mail"), .email)
    }
    func test_unknown_isOther() {
        XCTAssertEqual(AppCategory.category(forBundleId: "com.random.app"), .other)
        XCTAssertEqual(AppCategory.category(forBundleId: nil), .other)
    }
}
