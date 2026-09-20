import XCTest
@testable import Lotti

final class PolishServiceTests: XCTestCase {
    func test_body_includesModelAndRawText() throws {
        let data = PolishRequest.body(for: "helo wrld")
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["model"] as? String, "claude-haiku-4-5")
        let messages = obj["messages"] as! [[String: Any]]
        XCTAssertTrue("\(messages)".contains("helo wrld"))
    }
    func test_parsesResponseText() {
        let json = """
        {"content":[{"type":"text","text":"Hello, world."}]}
        """.data(using: .utf8)!
        XCTAssertEqual(PolishRequest.text(fromResponse: json), "Hello, world.")
    }
    func test_parsesResponse_ignoresNonText() {
        let json = """
        {"content":[{"type":"thinking","text":"x"},{"type":"text","text":"Final."}]}
        """.data(using: .utf8)!
        XCTAssertEqual(PolishRequest.text(fromResponse: json), "Final.")
    }
}
