import SwiftUI

struct BestsTab: View {
    let store: Store
    private var items: [Dictation] { store.all() }
    private var stats: Stats { store.stats(now: .now) }

    private var wordsPerDay: [Date: Int] {
        let cal = Calendar.current
        var m: [Date: Int] = [:]
        for item in items { m[cal.startOfDay(for: item.createdAt), default: 0] += item.wordCount }
        return m
    }
    private var bestDay: Int { wordsPerDay.values.max() ?? 0 }
    private var wordsPerWeek: [Int: Int] {
        let cal = Calendar.current
        var m: [Int: Int] = [:]
        for item in items {
            let week = cal.component(.weekOfYear, from: item.createdAt)
            m[week, default: 0] += item.wordCount
        }
        return m
    }
    private var bestWeek: Int { wordsPerWeek.values.max() ?? 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            statCard(value: "\(bestDay)", label: "BEST DAY (WORDS)")
            statCard(value: "\(bestWeek)", label: "BEST WEEK (WORDS)")
            statCard(value: "\(stats.longestStreak)", label: "LONGEST STREAK (DAYS)")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.gsBold(34)).foregroundStyle(Color.appTextPrimary)
            Text(label).font(.gsMedium(11)).foregroundStyle(Color.appTextSecondary).tracking(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}
