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

    func test_body_shortInput_usesFloorMaxTokens() throws {
        let obj = try JSONSerialization.jsonObject(with: PolishRequest.body(for: "hi")) as! [String: Any]
        XCTAssertEqual(obj["max_tokens"] as? Int, 512)
    }

    func test_body_longInput_scalesButCapsMaxTokens() throws {
        let long = String(repeating: "word ", count: 5000) // ~25k chars
        let obj = try JSONSerialization.jsonObject(with: PolishRequest.body(for: long)) as! [String: Any]
        XCTAssertEqual(obj["max_tokens"] as? Int, 4096, "long input must be capped, never truncated below cap")
    }

    func test_body_systemPromptIsCached() throws {
        let obj = try JSONSerialization.jsonObject(with: PolishRequest.body(for: "x")) as! [String: Any]
        let system = obj["system"] as! [[String: Any]]
        XCTAssertEqual((system.first?["cache_control"] as? [String: Any])?["type"] as? String, "ephemeral")
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
