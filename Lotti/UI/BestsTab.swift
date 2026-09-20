import SwiftUI

struct BestsTab: View {
    let snapshot: InsightsSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            statCard(value: "\(snapshot.bestDay)", label: "BEST DAY (WORDS)")
            statCard(value: "\(snapshot.bestWeek)", label: "BEST WEEK (WORDS)")
            statCard(value: "\(snapshot.stats.longestStreak)", label: "LONGEST STREAK (DAYS)")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.gsBold(34)).foregroundStyle(Color.appTextPrimary)
            Text(label).font(.gsMedium(11)).foregroundStyle(Color.appTextSecondary).tracking(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCardStyle()
    }
}
