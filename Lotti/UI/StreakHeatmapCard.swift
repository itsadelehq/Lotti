import SwiftUI

struct StreakHeatmapCard: View {
    let items: [Dictation]
    let longestStreak: Int
    var currentStreak: Int = 0

    private let weeks = 17
    private let cell: CGFloat = 16
    private let gap: CGFloat = 6
    private let labelGrey = Color(hex: 0x707070)

    /// Per-day word totals, computed once at init (not per render / per cell).
    private let wordsPerDay: [Date: Int]
    /// Quartile activity level (1...4) for each active day, computed once at
    /// init from `wordsPerDay` so `colorFor` is a cheap O(1) lookup instead of
    /// recomputing buckets on every cell of every render.
    private let cellLevels: [Date: Int]

    init(items: [Dictation], longestStreak: Int, currentStreak: Int = 0) {
        self.items = items
        self.longestStreak = longestStreak
        self.currentStreak = currentStreak

        let cal = Calendar.current
        var perDay: [Date: Int] = [:]
        for item in items { perDay[cal.startOfDay(for: item.createdAt), default: 0] += item.wordCount }
        self.wordsPerDay = perDay
        self.cellLevels = Self.computeLevels(from: perDay)
    }

    /// Buckets each active day's word count into quartiles (1 = lowest
    /// activity ... 4 = highest), computed once and reused for every cell.
    private static func computeLevels(from wordsPerDay: [Date: Int]) -> [Date: Int] {
        let activeCounts = wordsPerDay.values.filter { $0 > 0 }.sorted()
        guard !activeCounts.isEmpty else { return [:] }

        func threshold(_ p: Double) -> Int {
            let idx = min(activeCounts.count - 1, Int(Double(activeCounts.count) * p))
            return activeCounts[idx]
        }
        let q1 = threshold(0.25), q2 = threshold(0.5), q3 = threshold(0.75)

        var levels: [Date: Int] = [:]
        for (date, n) in wordsPerDay where n > 0 {
            let level: Int
            if n <= q1 { level = 1 }
            else if n <= q2 { level = 2 }
            else if n <= q3 { level = 3 }
            else { level = 4 }
            levels[date] = level
        }
        return levels
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
        // Future / no-data days render in a faint warm off-white.
        if date > Calendar.current.startOfDay(for: .now) { return .figHeatFuture }
        guard let level = cellLevels[date] else { return .figHeatEmpty }
        // Occasional light-purple accent cells among active days, for variety.
        let day = Calendar.current.component(.day, from: date)
        if day % 11 == 0 { return .figLilac }
        switch level {
        case 1: return .figPeriwinkle1
        case 2: return .figPeriwinkle2
        case 3: return .figPeriwinkle3
        default: return .figPeriwinkle4
        }
    }

    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(currentStreak) day streak").font(.gsBold(AppFontSizes.sectionHeading)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Text("LONGEST STREAK").font(.gsMedium(11)).foregroundStyle(Color.appTextSecondary).tracking(0.8)
                    Text("|").foregroundStyle(Color.appTextSecondary.opacity(0.5))
                    Text("\(longestStreak) DAYS").font(.gsBold(13)).foregroundStyle(Color.appTextPrimary)
                }
            }

            // Month labels row with chevrons, evenly distributed above each
            // month's column of the grid (rather than packed to the left).
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 9)).foregroundStyle(Color.appTextSecondary)
                // Align with the day-label gutter, then lay out the grid width.
                Color.clear.frame(width: 30)
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(monthLabels.enumerated()), id: \.offset) { idx, label in
                            if !label.isEmpty {
                                Text(label)
                                    .font(.gsMedium(10))
                                    .foregroundStyle(labelGrey)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .position(
                                        x: (CGFloat(idx) + 0.5) / CGFloat(weeks) * geo.size.width,
                                        y: 6
                                    )
                            }
                        }
                    }
                }
                .frame(height: 12)
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Color.appTextSecondary)
            }

            // Day-of-week labels + grid.
            HStack(alignment: .top, spacing: gap) {
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(0..<7, id: \.self) { r in
                        Text(dayLabels[r])
                            .font(.gsRegular(9))
                            .foregroundStyle(labelGrey)
                            .frame(width: 26, height: cell, alignment: .leading)
                    }
                }
                ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                    VStack(spacing: gap) {
                        ForEach(col, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(colorFor(day))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }

            // Legend.
            HStack(spacing: 6) {
                Text("More").font(.gsRegular(11)).foregroundStyle(Color.appTextSecondary)
                ForEach(Array(Color.heatmapLegend.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 11, height: 11)
                }
                Text("Less").font(.gsRegular(11)).foregroundStyle(Color.appTextSecondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCardStyle()
    }
}
