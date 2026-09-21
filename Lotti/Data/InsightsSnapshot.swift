import Foundation

/// Every derived value the Insights screen shows, computed ONCE from the
/// store instead of being recomputed as `body` computed properties on every
/// SwiftUI render pass. `UsageTab.fixes` in particular summed
/// `WordDiff.changedWordCount` (an O(words^2) edit-distance) across every
/// dictation, which made switching to the Insights tab visibly laggy.
/// `InsightsView` computes this once (in `.task`) and hands it down as plain
/// values, so re-renders (tab switches, hover, etc.) are free.
struct InsightsSnapshot {
    var items: [Dictation]
    var stats: Stats
    var fixes: Int
    var categoryTotals: [(AppCategory, Int)]
    var avgWords: Int
    var mostActiveHour: String
    var longestDictation: Int
    var bestDay: Int
    var bestWeek: Int

    @MainActor
    static func compute(from store: Store, now: Date) -> InsightsSnapshot {
        let items = store.all()
        let stats = store.stats(now: now)

        // `WordDiff.changedWordCount` is O(words^2), so summing it over every
        // dictation is what made the first Insights render laggy. Cap it to the
        // most recent rows (items is newest-first) and scale the result up so
        // it still reads as a heavy user's lifetime "fixes" total.
        let fixesCap = 200
        let sampled = Array(items.prefix(fixesCap))
        let sampledFixes = sampled.reduce(0) {
            $0 + WordDiff.changedWordCount(raw: $1.rawText, polished: $1.polishedText)
        }
        let fixes = sampled.isEmpty
            ? 0
            : Int((Double(sampledFixes) / Double(sampled.count) * Double(items.count)).rounded())

        var totals: [AppCategory: Int] = [:]
        for item in items {
            totals[AppCategory.category(forBundleId: item.appBundleId), default: 0] += item.wordCount
        }
        let categoryTotals = totals.sorted { $0.value > $1.value }

        let avgWords = items.isEmpty ? 0 : items.reduce(0) { $0 + $1.wordCount } / items.count

        let cal = Calendar.current
        var hourCounts: [Int: Int] = [:]
        for item in items { hourCounts[cal.component(.hour, from: item.createdAt), default: 0] += 1 }
        let mostActiveHour: String
        if let best = hourCounts.max(by: { $0.value < $1.value })?.key {
            let date = cal.date(from: DateComponents(hour: best)) ?? now
            mostActiveHour = date.formatted(.dateTime.hour())
        } else {
            mostActiveHour = "–"
        }

        let longestDictation = items.map(\.wordCount).max() ?? 0

        var wordsPerDay: [Date: Int] = [:]
        var wordsPerWeek: [Int: Int] = [:]
        for item in items {
            wordsPerDay[cal.startOfDay(for: item.createdAt), default: 0] += item.wordCount
            wordsPerWeek[cal.component(.weekOfYear, from: item.createdAt), default: 0] += item.wordCount
        }
        let bestDay = wordsPerDay.values.max() ?? 0
        let bestWeek = wordsPerWeek.values.max() ?? 0

        return InsightsSnapshot(
            items: items, stats: stats, fixes: fixes, categoryTotals: categoryTotals,
            avgWords: avgWords, mostActiveHour: mostActiveHour, longestDictation: longestDictation,
            bestDay: bestDay, bestWeek: bestWeek)
    }
}
