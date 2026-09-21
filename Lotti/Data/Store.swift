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

        // Realistic per-day dictations: many short/medium messages that read
        // like real dictated text, adding up to a heavy-user total (~250K+).
        let targetWpm = 105.0
        for offset in sortedOffsets {
            guard let base = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let perDay = 3 + rnd(4) // 3–6 dictations that day (a few hundred rows total)
            for _ in 0..<perDay {
                // Larger per-dictation counts so the lifetime total still reads
                // as a heavy user (~150K–250K words) despite far fewer rows.
                let words = 180 + rnd(520) // 180–699 words, always readable
                let hour = 8 + rnd(12)
                let minute = rnd(60)
                let when = cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
                let polished = Self.filler(words: words, seed: &seed)
                let raw = Self.corrupt(polished, edits: 1 + rnd(6), seed: &seed)
                let actual = polished.split(whereSeparator: { $0.isWhitespace }).count
                let wpm = targetWpm + Double(rnd(20) - 10)
                let duration = Double(actual) / (wpm / 60.0)
                let app = apps[rnd(apps.count)]
                context.insert(Dictation(rawText: raw, polishedText: polished,
                                         appBundleId: app == "other" ? nil : app,
                                         durationSeconds: duration, createdAt: when))
            }
        }
        try? context.save()
    }

    private static let words = ["the","quick","meeting","notes","let's","align","on","project",
        "timeline","and","budget","for","next","quarter","please","review","the","draft",
        "before","tomorrow","thanks","idea","update","the","doc","with","latest","numbers",
        "send","summary","to","team","great","work","everyone","follow","up","soon"]

    private static let sentenceBank: [String] = [
        "Let's align on the project timeline and budget for next quarter.",
        "Please review the draft before tomorrow and send me any notes.",
        "I updated the document with the latest numbers and shared it with the team.",
        "Can you follow up with the client about the contract renewal this week?",
        "Great work everyone, let's keep the momentum going into next sprint.",
        "I think we should prioritise the onboarding flow before the launch.",
        "Quick reminder to submit your expenses by the end of the day.",
        "The meeting notes are in the shared folder if you want to catch up.",
        "Let's schedule a call to walk through the proposal in more detail.",
        "I've drafted a reply to the customer and I'd love a second pair of eyes.",
        "We're on track to ship the update by the end of the month.",
        "Thanks for jumping on this so quickly, it really helped unblock the team.",
        "Let me know if the new design direction works for you.",
        "I'll circle back once I've had a chance to test the changes.",
        "Can we push the deadline by a couple of days to get this right?",
        "The analytics show a nice bump in engagement since the last release.",
        "I'm going to take some notes during the interview and summarise after.",
        "Let's keep the scope tight for version one and iterate from there.",
        "Reaching out to confirm our meeting for tomorrow afternoon.",
        "I really appreciate the thoughtful feedback on the last draft.",
    ]

    /// Builds clean, realistic dictated text of roughly `count` words.
    private static func filler(words count: Int, seed: inout UInt64) -> String {
        func rnd(_ n: Int) -> Int {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Int(seed % UInt64(max(1, n)))
        }
        var parts: [String] = []
        var wordsSoFar = 0
        while wordsSoFar < count {
            let s = sentenceBank[rnd(sentenceBank.count)]
            parts.append(s)
            wordsSoFar += s.split(separator: " ").count
        }
        return parts.joined(separator: " ")
    }

    /// Produces a lightly "misrecognised" raw version of `text` by swapping a
    /// few words for plausible transcription slips, so WordDiff finds real edits.
    private static func corrupt(_ text: String, edits: Int, seed: inout UInt64) -> String {
        func rnd(_ n: Int) -> Int {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Int(seed % UInt64(max(1, n)))
        }
        let swaps: [String: String] = [
            "their": "there", "there": "their", "to": "too", "your": "you're",
            "let's": "lets", "we're": "were", "I'd": "id", "I've": "ive",
            "into": "in to", "before": "be for", "quarter": "quater",
        ]
        var tokens = text.split(separator: " ").map(String.init)
        var made = 0
        var i = 0
        while i < tokens.count && made < edits {
            let key = tokens[i].lowercased()
            if let rep = swaps[key], rnd(2) == 0 {
                tokens[i] = rep; made += 1
            }
            i += 1
        }
        // Ensure at least one visible edit so the fixes metric is non-zero.
        if made == 0, !tokens.isEmpty { tokens[0] = tokens[0].lowercased() }
        return tokens.joined(separator: " ")
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
