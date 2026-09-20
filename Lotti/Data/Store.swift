import Foundation
import SwiftData

struct Stats { let totalWords: Int; let wpm: Int; let currentStreak: Int; let longestStreak: Int }

@MainActor final class Store: ObservableObject {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try! ModelContainer(for: Dictation.self, configurations: config)
    }
    func add(_ d: Dictation) { context.insert(d); try? context.save() }
    func all() -> [Dictation] {
        (try? context.fetch(FetchDescriptor<Dictation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }
    func stats(now: Date) -> Stats {
        let items = all()
        let totalWords = items.reduce(0) { $0 + $1.wordCount }
        let totalSeconds = items.reduce(0.0) { $0 + $1.durationSeconds }
        let totalWordsForWpm = items.reduce(0) { $0 + $1.wordCount }
        let wpm = totalSeconds > 0 ? Int((Double(totalWordsForWpm) / (totalSeconds / 60)).rounded()) : 0
        let (cur, longest) = Self.streaks(items.map(\.createdAt), now: now)
        return Stats(totalWords: totalWords, wpm: wpm, currentStreak: cur, longestStreak: longest)
    }
    static func streaks(_ dates: [Date], now: Date) -> (current: Int, longest: Int) {
        let cal = Calendar.current
        let days = Set(dates.map { cal.startOfDay(for: $0) }).sorted()
        guard !days.isEmpty else { return (0, 0) }
        var longest = 1, run = 1
        if days.count > 1 {
            for i in 1..<days.count {
                if cal.date(byAdding: .day, value: 1, to: days[i-1]) == days[i] { run += 1 }
                else { run = 1 }
                longest = max(longest, run)
            }
        }
        // current streak ending today
        var current = 0
        var cursor = cal.startOfDay(for: now)
        let daySet = Set(days)
        while daySet.contains(cursor) {
            current += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (current, max(longest, current))
    }
}
