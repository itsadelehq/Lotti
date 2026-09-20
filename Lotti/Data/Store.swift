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
    /// Removes every stored dictation. Used by a Settings "Clear demo data" action.
    func clearAll() {
        for d in all() { context.delete(d) }
        try? context.save()
    }

    /// Seeds a heavy power-user's worth of demo dictations (~300K–350K total
    /// words, WPM ~100–110, a multi-day current streak, a longest streak of
    /// ~18 days, spread across the last ~17 weeks), but only when the store
    /// is empty, so the Insights screen mirrors a real Wispr-scale user
    /// without ever overwriting a real user's history or double-seeding.
    /// Uses a few hundred rows with moderate per-dictation word counts (never
    /// tens of thousands of tiny rows) to stay fast, including for
    /// `WordDiff.changedWordCount`'s O(words²) comparison.
    func seedDemoDataIfEmpty(now: Date = .now) {
        guard all().isEmpty else { return }
        let cal = Calendar.current
        let apps = [
            "com.openai.chat", "com.openai.chat", "com.openai.chat", "com.openai.chat",
            "com.anthropic.claude", "com.anthropic.claude",
            "com.tinyspeck.slackmacgap", "com.tinyspeck.slackmacgap", "com.tinyspeck.slackmacgap",
            "com.apple.mail", "com.apple.mail",
            "notion.id", "md.obsidian",
            "com.apple.Messages", "com.apple.Messages",
            "other",
        ]
        // Deterministic pseudo-random so the demo looks the same each launch.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd(_ upper: Int) -> Int {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Int(seed % UInt64(max(1, upper)))
        }

        let today = cal.startOfDay(for: now)
        let windowDays = 121 // ~17 weeks

        // Build the active-day set: a multi-day current streak, a dedicated
        // ~18-day run earlier in the window (bounded by rest days on either
        // side so it reads as exactly the longest streak), periodic rest
        // days elsewhere so no other run exceeds it, and otherwise dense
        // coverage so the heatmap looks well-filled like a heavy user's.
        var activeOffsets = Set<Int>()
        for d in 0..<7 { activeOffsets.insert(d) }         // current streak: 7 days
        for d in 30..<48 { activeOffsets.insert(d) }       // longest streak: 18 days
        for d in 7..<windowDays {
            if d >= 29 && d < 49 { continue }              // rest days bounding the 18-day run
            if d % 15 == 14 { continue }                   // periodic rest day caps other runs
            if rnd(100) < 85 { activeOffsets.insert(d) }
        }
        let sortedOffsets = activeOffsets.sorted()

        // Distribute a ~325K-word budget across the active days so the total
        // lands in the 300K–350K range with a realistic per-day spread.
        var remainingWords = 325_000
        let targetWpm = 105.0

        for (idx, offset) in sortedOffsets.enumerated() {
            guard let base = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let remainingDays = sortedOffsets.count - idx
            let dayBudget = max(120, remainingWords / max(1, remainingDays))
            let perDay = 2 + rnd(4) // 2–5 dictations that day
            var dayRemaining = dayBudget
            for i in 0..<perDay {
                let isLast = i == perDay - 1
                let share = isLast ? dayRemaining : max(60, dayRemaining / (perDay - i) + rnd(120) - 60)
                let words = min(900, max(60, share))
                let hour = 8 + rnd(12)
                let minute = rnd(60)
                let when = cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
                let raw = Self.filler(words: words)
                let polished = Self.filler(words: words, corrected: 2 + rnd(10))
                let wpm = targetWpm + Double(rnd(20) - 10) // ~95–115, averages to ~105
                let duration = Double(words) / (wpm / 60.0)
                let app = apps[rnd(apps.count)]
                context.insert(Dictation(rawText: raw, polishedText: polished,
                                         appBundleId: app == "other" ? nil : app,
                                         durationSeconds: duration, createdAt: when))
                dayRemaining -= words
                remainingWords -= words
            }
        }
        try? context.save()
    }

    private static let words = ["the","quick","meeting","notes","let's","align","on","project",
        "timeline","and","budget","for","next","quarter","please","review","the","draft",
        "before","tomorrow","thanks","idea","update","the","doc","with","latest","numbers",
        "send","summary","to","team","great","work","everyone","follow","up","soon"]

    private static func filler(words count: Int, corrected: Int = 0) -> String {
        var out: [String] = []
        for i in 0..<count { out.append(words[i % words.count]) }
        // Introduce a few differing tokens so WordDiff.changedWordCount is non-zero.
        for i in 0..<min(corrected, out.count) { out[i] = out[i] + "x" }
        return out.joined(separator: " ")
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
