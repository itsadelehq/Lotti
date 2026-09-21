import XCTest
@testable import Lotti

final class SummaryServiceTests: XCTestCase {
    func test_body_includesModelAndText() throws {
        let data = SummaryRequest.body(for: "buy milk and call Sam")
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["model"] as? String, "claude-haiku-4-5")
        XCTAssertEqual(obj["max_tokens"] as? Int, 700)
        let messages = obj["messages"] as! [[String: Any]]
        XCTAssertTrue("\(messages)".contains("buy milk and call Sam"))
    }
    func test_parsesResponseText() {
        let json = """
        {"content":[{"type":"text","text":"Summary here."}]}
        """.data(using: .utf8)!
        XCTAssertEqual(SummaryRequest.text(fromResponse: json), "Summary here.")
    }
    func test_parsesResponse_ignoresNonText() {
        let json = """
        {"content":[{"type":"thinking","text":"x"},{"type":"text","text":"Final."}]}
        """.data(using: .utf8)!
        XCTAssertEqual(SummaryRequest.text(fromResponse: json), "Final.")
    }
}
