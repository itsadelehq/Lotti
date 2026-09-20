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

    /// Seeds ~40 realistic dictations across the last ~16 weeks, but only when the
    /// store is empty, so the Insights screen looks populated without ever
    /// overwriting a real user's history or double-seeding.
    func seedDemoDataIfEmpty(now: Date = .now) {
        guard all().isEmpty else { return }
        let cal = Calendar.current
        let apps = [
            "com.openai.chat", "com.openai.chat", "com.openai.chat",
            "com.anthropic.claude",
            "com.tinyspeck.slackmacgap", "com.tinyspeck.slackmacgap",
            "com.apple.mail",
            "notion.id", "md.obsidian",
            "com.apple.Messages",
            "other",
        ]
        // Deterministic pseudo-random so the demo looks the same each launch.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd(_ upper: Int) -> Int {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Int(seed % UInt64(max(1, upper)))
        }

        let today = cal.startOfDay(for: now)
        // Build an active-day set that yields a multi-day current streak and a
        // longest streak around 18. Days counted back from today.
        var activeOffsets = Set<Int>()
        for d in 0..<6 { activeOffsets.insert(d) }        // current streak ~6 days
        for d in 20..<38 { activeOffsets.insert(d) }      // an 18-day run earlier
        // Scatter extra single days across the 16-week window.
        for _ in 0..<20 { activeOffsets.insert(7 + rnd(105)) }

        var inserted = 0
        for offset in activeOffsets.sorted() {
            guard let base = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let perDay = 1 + rnd(3) // 1–3 dictations that day
            for _ in 0..<perDay {
                let hour = 8 + rnd(12)
                let minute = rnd(60)
                let when = cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
                let words = 25 + rnd(180)
                let raw = Self.filler(words: words)
                let polished = Self.filler(words: words, corrected: 2 + rnd(6))
                let duration = Double(words) / (2.0 + Double(rnd(2))) // ~120–180 wpm
                let app = apps[rnd(apps.count)]
                context.insert(Dictation(rawText: raw, polishedText: polished,
                                         appBundleId: app == "other" ? nil : app,
                                         durationSeconds: duration, createdAt: when))
                inserted += 1
            }
            if inserted >= 60 { break }
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
