import XCTest
@testable import Lotti

@MainActor
final class StoreTests: XCTestCase {
    func makeStore() -> Store { Store(inMemory: true) }

    func test_totalWords_sumsPolishedWordCounts() {
        let s = makeStore()
        s.add(Dictation(rawText: "a b c", polishedText: "one two three", durationSeconds: 10))
        s.add(Dictation(rawText: "x", polishedText: "four five", durationSeconds: 5))
        XCTAssertEqual(s.stats(now: .now).totalWords, 5)
    }
    func test_wpm_usesWordsOverMinutes() {
        let s = makeStore()
        // 60 words over 60 seconds = 60 wpm
        let words = Array(repeating: "w", count: 60).joined(separator: " ")
        s.add(Dictation(rawText: words, polishedText: words, durationSeconds: 60))
        XCTAssertEqual(s.stats(now: .now).wpm, 60)
    }
    func test_currentStreak_countsConsecutiveDays() {
        let s = makeStore()
        let cal = Calendar.current
        let today = Date()
        for offset in 0..<3 {
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            s.add(Dictation(rawText: "x", polishedText: "hi", durationSeconds: 1, createdAt: d))
        }
        XCTAssertEqual(s.stats(now: today).currentStreak, 3)
    }
    func test_streakBreaks_onGap() {
        let s = makeStore()
        let cal = Calendar.current
        let today = Date()
        s.add(Dictation(rawText: "x", polishedText: "hi", durationSeconds: 1, createdAt: today))
        let old = cal.date(byAdding: .day, value: -2, to: today)!
        s.add(Dictation(rawText: "x", polishedText: "hi", durationSeconds: 1, createdAt: old))
        XCTAssertEqual(s.stats(now: today).currentStreak, 1)
    }
}
