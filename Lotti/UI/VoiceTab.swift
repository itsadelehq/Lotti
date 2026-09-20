import SwiftUI

struct VoiceTab: View {
    let store: Store
    private var items: [Dictation] { store.all() }

    private var avgWords: Int {
        items.isEmpty ? 0 : items.reduce(0) { $0 + $1.wordCount } / items.count
    }
    private var mostActiveHour: String {
        guard !items.isEmpty else { return "–" }
        let cal = Calendar.current
        var counts: [Int: Int] = [:]
        for item in items { counts[cal.component(.hour, from: item.createdAt), default: 0] += 1 }
        guard let best = counts.max(by: { $0.value < $1.value })?.key else { return "–" }
        let comps = DateComponents(hour: best)
        let date = cal.date(from: comps) ?? .now
        return date.formatted(.dateTime.hour())
    }
    private var longestDictation: Int {
        items.map(\.wordCount).max() ?? 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            statCard(value: "\(avgWords)", label: "AVG WORDS / DICTATION")
            statCard(value: mostActiveHour, label: "MOST ACTIVE HOUR")
            statCard(value: "\(longestDictation)", label: "LONGEST DICTATION (WORDS)")
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
