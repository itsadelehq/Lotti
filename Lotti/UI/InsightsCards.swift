import SwiftUI

private func cardLabel(_ text: String) -> some View {
    Text(text)
        .font(.gsMedium(11))
        .foregroundStyle(Color.appTextSecondary)
        .tracking(0.6)
}

struct WpmGaugeCard: View {
    let wpm: Int
    /// Where wpm ranks vs a reference distribution; purely illustrative.
    private var topPercent: Int { max(1, min(99, 100 - min(wpm, 200) / 2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(wpm)").font(.gsBold(38)).foregroundStyle(Color.appTextPrimary)
            cardLabel("WORDS PER MINUTE")
            HalfGauge(fraction: min(1, Double(wpm) / 200), centerText: "Top \(topPercent)%")
                .frame(height: 90)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}

struct HalfGauge: View {
    var fraction: Double
    var centerText: String
    var body: some View {
        ZStack {
            GaugeArc(fraction: 1).stroke(Color(hex: 0xE7E6E0), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            GaugeArc(fraction: fraction).stroke(Color.appTeal, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Text(centerText)
                .font(.gsMedium(12))
                .foregroundStyle(Color.appTextSecondary)
                .offset(y: 16)
        }
    }
}

struct GaugeArc: Shape {
    var fraction: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2
        p.addArc(center: center, radius: radius, startAngle: .degrees(180),
                  endAngle: .degrees(180 + 180 * fraction), clockwise: false)
        return p
    }
}

struct FixesCard: View {
    let fixes: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(fixes)").font(.gsBold(38)).foregroundStyle(Color.appTextPrimary)
            cardLabel("FIXES MADE BY FLOW")
            VStack(alignment: .leading, spacing: 4) {
                Text("\(fixes) words corrected").font(.gsRegular(13)).foregroundStyle(Color.appTextSecondary)
                Text("0 dictionary fixes").font(.gsRegular(13)).foregroundStyle(Color.appTextSecondary)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}

struct TotalWordsCard: View {
    let totalWords: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(totalWords)").font(.gsBold(38)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("▲ 195% this month")
                    .font(.gsMedium(11))
                    .foregroundStyle(Color.appGreenChipText)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.appGreenChipBg))
            }
            cardLabel("TOTAL WORDS DICTATED")
            Text("Desktop \(totalWords) words").font(.gsRegular(13)).foregroundStyle(Color.appTextSecondary)
                .padding(.top, 10)
            Text("Download on mobile")
                .font(.gsMedium(12))
                .foregroundStyle(Color.appTextPrimary)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().stroke(Color.appHairline))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}

struct DesktopUsageCard: View {
    let categoryTotals: [(AppCategory, Int)]
    private var total: Int { max(1, categoryTotals.reduce(0) { $0 + $1.1 }) }

    private func icon(for c: AppCategory) -> String {
        switch c {
        case .aiTools: "cpu"; case .messaging: "message"
        case .documents: "doc"; case .email: "envelope"; case .other: "infinity"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                cardLabel("TOTAL APPS USED")
                Spacer()
                Text("\(categoryTotals.count)").font(.gsBold(15)).foregroundStyle(Color.appTextPrimary)
            }
            if categoryTotals.isEmpty {
                Text("No app usage yet.").font(.gsRegular(13)).foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(categoryTotals, id: \.0) { cat, words in
                    let pct = Int((Double(words) / Double(total) * 100).rounded())
                    HStack(spacing: 10) {
                        Image(systemName: icon(for: cat)).foregroundStyle(Color.appTeal).frame(width: 18)
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.appCardMuted)
                                    Capsule().fill(Color.appTeal)
                                        .frame(width: geo.size.width * CGFloat(words) / CGFloat(total))
                                }
                            }
                            .frame(height: 8)
                            Text("\(pct)%  \(words) words · \(cat.rawValue)")
                                .font(.gsRegular(12)).foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}
