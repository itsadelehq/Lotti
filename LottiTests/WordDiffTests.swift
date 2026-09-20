import XCTest
@testable import Lotti

final class WordDiffTests: XCTestCase {
    func test_identical_isZero() {
        XCTAssertEqual(WordDiff.changedWordCount(raw: "hello world", polished: "hello world"), 0)
    }
    func test_oneSubstitution_isOne() {
        XCTAssertEqual(WordDiff.changedWordCount(raw: "i went their", polished: "i went there"), 1)
    }
    func test_insertion_counts() {
        XCTAssertEqual(WordDiff.changedWordCount(raw: "lets go", polished: "let us go"), 2)
    }
    func test_empty_raw() {
        XCTAssertEqual(WordDiff.changedWordCount(raw: "", polished: "two words"), 2)
    }
}
