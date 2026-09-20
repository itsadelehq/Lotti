import XCTest
@testable import Lotti

final class DeepgramMessageTests: XCTestCase {
    func test_parsesFinalTranscript() {
        let json = """
        {"is_final":true,"channel":{"alternatives":[{"transcript":"hello world"}]}}
        """.data(using: .utf8)!
        let r = DeepgramParser.transcript(from: json)
        XCTAssertEqual(r?.text, "hello world")
        XCTAssertEqual(r?.isFinal, true)
    }
    func test_parsesInterim() {
        let json = """
        {"is_final":false,"channel":{"alternatives":[{"transcript":"hel"}]}}
        """.data(using: .utf8)!
        XCTAssertEqual(DeepgramParser.transcript(from: json)?.isFinal, false)
    }
    func test_ignoresEmpty() {
        let json = """
        {"is_final":true,"channel":{"alternatives":[{"transcript":""}]}}
        """.data(using: .utf8)!
        XCTAssertNil(DeepgramParser.transcript(from: json))
    }
    func test_ignoresMetadata() {
        let json = #"{"type":"Metadata"}"#.data(using: .utf8)!
        XCTAssertNil(DeepgramParser.transcript(from: json))
    }
}
