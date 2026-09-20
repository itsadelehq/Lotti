import SwiftUI

struct VoiceTab: View {
    let snapshot: InsightsSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            statCard(value: "\(snapshot.avgWords)", label: "AVG WORDS / DICTATION")
            statCard(value: snapshot.mostActiveHour, label: "MOST ACTIVE HOUR")
            statCard(value: "\(snapshot.longestDictation)", label: "LONGEST DICTATION (WORDS)")
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
