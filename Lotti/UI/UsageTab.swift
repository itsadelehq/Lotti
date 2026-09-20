import SwiftUI

struct UsageTab: View {
    let store: Store

    private var items: [Dictation] { store.all() }
    private var stats: Stats { store.stats(now: .now) }
    private var fixes: Int {
        items.reduce(0) { $0 + WordDiff.changedWordCount(raw: $1.rawText, polished: $1.polishedText) }
    }
    private var categoryTotals: [(AppCategory, Int)] {
        var totals: [AppCategory: Int] = [:]
        for item in items {
            totals[AppCategory.category(forBundleId: item.appBundleId), default: 0] += item.wordCount
        }
        return totals.sorted { $0.value > $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                WpmGaugeCard(wpm: stats.wpm)
                FixesCard(fixes: fixes)
                TotalWordsCard(totalWords: stats.totalWords)
            }
            HStack(alignment: .top, spacing: 16) {
                DesktopUsageCard(categoryTotals: categoryTotals)
                StreakHeatmapCard(items: items, longestStreak: stats.longestStreak, currentStreak: stats.currentStreak)
            }
        }
    }
}
