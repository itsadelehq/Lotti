import SwiftUI

struct StreakHeatmapCard: View {
    let items: [Dictation]
    let longestStreak: Int

    private var weeks: Int { 16 }
    private var wordsPerDay: [Date: Int] {
        let cal = Calendar.current
        var m: [Date: Int] = [:]
        for item in items {
            m[cal.startOfDay(for: item.createdAt), default: 0] += item.wordCount
        }
        return m
    }
    /// Grid of `weeks` columns x 7 rows (Sun...Sat), oldest column first, ending this week.
    private var columns: [[Date]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        guard let thisSunday = cal.date(byAdding: .day, value: -(weekday - 1), to: today) else { return [] }
        return (0..<weeks).map { w in
            let colStart = cal.date(byAdding: .day, value: -7 * (weeks - 1 - w), to: thisSunday)!
            return (0..<7).map { d in cal.date(byAdding: .day, value: d, to: colStart)! }
        }
    }
    private func colorFor(_ date: Date) -> Color {
        let n = wordsPerDay[date] ?? 0
        switch n {
        case 0: return .heatmapScale[0]
        case 1..<50: return .heatmapScale[1]
        case 50..<150: return .heatmapScale[2]
        case 150..<400: return .heatmapScale[3]
        default: return .heatmapScale[4]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LONGEST STREAK").font(.gsMedium(11)).foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("\(longestStreak) DAYS").font(.gsBold(15)).foregroundStyle(Color.appTextPrimary)
            }
            HStack(alignment: .top, spacing: 3) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                    VStack(spacing: 3) {
                        ForEach(col, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(colorFor(day))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Spacer()
                Text("Less").font(.gsRegular(11)).foregroundStyle(Color.appTextSecondary)
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Color.heatmapScale[i]).frame(width: 10, height: 10)
                }
                Text("More").font(.gsRegular(11)).foregroundStyle(Color.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}
