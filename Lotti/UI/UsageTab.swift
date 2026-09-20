import SwiftUI

struct UsageTab: View {
    let snapshot: InsightsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                WpmGaugeCard(wpm: snapshot.stats.wpm)
                FixesCard(fixes: snapshot.fixes)
                TotalWordsCard(totalWords: snapshot.stats.totalWords)
            }
            HStack(alignment: .top, spacing: 16) {
                DesktopUsageCard(categoryTotals: snapshot.categoryTotals)
                StreakHeatmapCard(items: snapshot.items, longestStreak: snapshot.stats.longestStreak, currentStreak: snapshot.stats.currentStreak)
            }
        }
    }
}
