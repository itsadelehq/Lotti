import SwiftUI

struct StreakHeatmapCard: View {
    let items: [Dictation]
    let longestStreak: Int
    var currentStreak: Int = 0

    private let weeks = 17
    private let cell: CGFloat = 13
    private let gap: CGFloat = 3

    private var wordsPerDay: [Date: Int] {
        let cal = Calendar.current
        var m: [Date: Int] = [:]
        for item in items { m[cal.startOfDay(for: item.createdAt), default: 0] += item.wordCount }
        return m
    }

    /// `weeks` columns x 7 rows (Sun...Sat), oldest first, ending this week.
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

    /// Month label for each column, shown only when the month changes.
    private var monthLabels: [String] {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "MMM"
        var last = -1
        return columns.map { col in
            let m = cal.component(.month, from: col[0])
            if m != last { last = m; return fmt.string(from: col[0]) }
            return ""
        }
    }

    private func colorFor(_ date: Date) -> Color {
        // Days in the future render as empty warm-grey.
        if date > Calendar.current.startOfDay(for: .now) { return .heatmapMixed[0] }
        let n = wordsPerDay[date] ?? 0
        switch n {
        case 0: return .heatmapMixed[0]
        case 1..<60: return .heatmapMixed[1]
        case 60..<160: return .heatmapMixed[2]
        case 160..<340: return .heatmapMixed[3]
        default: return .heatmapMixed[4]
        }
    }

    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(currentStreak) day streak").font(.gsBold(28)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Text("LONGEST STREAK").font(.gsMedium(11)).foregroundStyle(Color.appTextSecondary).tracking(0.8)
                    Text("|").foregroundStyle(Color.appTextSecondary.opacity(0.5))
                    Text("\(longestStreak) DAYS").font(.gsBold(13)).foregroundStyle(Color.appTextPrimary)
                }
            }

            // Month labels row with chevrons.
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 9)).foregroundStyle(Color.appTextSecondary)
                HStack(alignment: .top, spacing: 0) {
                    // Spacer to align with the day-label gutter.
                    Color.clear.frame(width: 30)
                    ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.gsMedium(10))
                            .foregroundStyle(Color.appTextSecondary)
                            .frame(width: cell + gap, alignment: .leading)
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Color.appTextSecondary)
            }

            // Day-of-week labels + grid.
            HStack(alignment: .top, spacing: gap) {
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(0..<7, id: \.self) { r in
                        Text(dayLabels[r])
                            .font(.gsRegular(9))
                            .foregroundStyle(Color.appTextSecondary)
                            .frame(width: 26, height: cell, alignment: .leading)
                    }
                }
                ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                    VStack(spacing: gap) {
                        ForEach(col, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(colorFor(day))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }

            // Legend.
            HStack(spacing: 6) {
                Text("More").font(.gsRegular(11)).foregroundStyle(Color.appTextSecondary)
                ForEach((0..<5).reversed(), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Color.heatmapMixed[i]).frame(width: 11, height: 11)
                }
                Text("Less").font(.gsRegular(11)).foregroundStyle(Color.appTextSecondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCardStyle()
    }
}
