import SwiftUI

// MARK: - Shared bits

/// Small-caps grey label with letter-spacing, optional trailing info icon.
private struct CardLabel: View {
    let text: String
    var info: Bool = false
    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.gsMedium(11))
                .foregroundStyle(Color.appTextSecondary)
                .tracking(0.8)
            if info {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appTextSecondary.opacity(0.7))
            }
        }
    }
}

private func bigNumber(_ n: Int) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

// MARK: - WPM gauge card

struct WpmGaugeCard: View {
    let wpm: Int
    private var topPercent: Int { max(1, min(99, 100 - min(wpm, 200) / 2)) }
    /// Fill 75–95% of the semicircle so the gauge always looks substantial.
    private var fraction: Double { 0.75 + min(0.20, Double(wpm) / 1000.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(wpm)").font(.gsBold(46)).foregroundStyle(Color.appTextPrimary)
            CardLabel(text: "WORDS PER MINUTE", info: true)
            HalfGauge(fraction: fraction, centerText: "Top \(topPercent)%")
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCardStyle()
        .frame(width: 230, height: 216)
    }
}

struct HalfGauge: View {
    var fraction: Double
    var centerText: String
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(w / 2, h) - 8
            let center = CGPoint(x: w / 2, y: h)
            let endAngle = Angle.degrees(180 + 180 * min(1, fraction))
            ZStack {
                GaugeArc(fraction: 1)
                    .stroke(Color.appGaugeTrack, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                GaugeArc(fraction: min(1, fraction))
                    .stroke(Color.figPeriwinkleMed, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                // Small grey knob at the arc end.
                Circle()
                    .fill(Color(hex: 0xBFBEB6))
                    .frame(width: 10, height: 10)
                    .position(
                        x: center.x + radius * CGFloat(cos(endAngle.radians)),
                        y: center.y + radius * CGFloat(sin(endAngle.radians))
                    )
                Text(centerText)
                    .font(.gsBold(15))
                    .foregroundStyle(Color.appTextPrimary)
                    .position(x: w / 2, y: h - 14)
            }
        }
    }
}

struct GaugeArc: Shape {
    var fraction: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2, rect.height) - 8
        p.addArc(center: center, radius: radius, startAngle: .degrees(180),
                  endAngle: .degrees(180 + 180 * fraction), clockwise: false)
        return p
    }
}

// MARK: - Fixes card

struct FixesCard: View {
    let fixes: Int
    private var dictionaryFixes: Int { max(0, fixes / 9) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bigNumber(fixes)).font(.gsBold(46)).foregroundStyle(Color.appTextPrimary)
            CardLabel(text: "FIXES MADE BY LOTTI")
            VStack(alignment: .leading, spacing: 10) {
                subRow(value: fixes, label: "words corrected")
                subRow(value: dictionaryFixes, label: "dictionary fixes")
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCardStyle()
        .frame(width: 210, height: 216)
    }

    private func subRow(value: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Text("\(bigNumber(value)) \(label)")
                .font(.gsRegular(13))
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(Color.appTextSecondary.opacity(0.7))
        }
    }
}

// MARK: - Total words card

struct TotalWordsCard: View {
    let totalWords: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(bigNumber(totalWords)).font(.gsBold(46)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold))
                    Text("195% this month").font(.gsMedium(11))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.figChipYellow))
            }
            CardLabel(text: "TOTAL WORDS DICTATED")
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appTextSecondary)
                    Text("Desktop \(bigNumber(totalWords)) words")
                        .font(.gsRegular(13))
                        .foregroundStyle(Color.appTextPrimary)
                }
                Spacer()
                Text("Download on mobile")
                    .font(.gsMedium(12))
                    .foregroundStyle(Color.appTextPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        Capsule().stroke(Color.appTextSecondary.opacity(0.35), lineWidth: 1)
                    )
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCardStyle()
        .frame(maxWidth: .infinity)
        .frame(height: 216)
    }
}

// MARK: - Desktop usage card

struct DesktopUsageCard: View {
    let categoryTotals: [(AppCategory, Int)]
    private var total: Int { max(1, categoryTotals.reduce(0) { $0 + $1.1 }) }
    private var maxWords: Int { max(1, categoryTotals.first?.1 ?? 1) }

    private func icon(for c: AppCategory) -> String {
        switch c {
        case .aiTools: "cpu"; case .messaging: "message"
        case .documents: "doc.text"; case .email: "envelope"; case .other: "infinity"
        }
    }
    private func noun(for c: AppCategory) -> String {
        switch c {
        case .aiTools: "AI PROMPTS"; case .messaging: "MESSAGES"
        case .documents: "DOCUMENTS"; case .email: "EMAILS"; case .other: "OTHER TASKS"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Desktop usage").font(.gsSemibold(26)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Text("TOTAL APPS USED").font(.gsMedium(11)).foregroundStyle(Color.appTextSecondary).tracking(0.8)
                    Text("|").foregroundStyle(Color.appTextSecondary.opacity(0.5))
                    Text("\(categoryTotals.count)").font(.gsBold(13)).foregroundStyle(Color.appTextPrimary)
                }
            }
            if categoryTotals.isEmpty {
                Text("No app usage yet.").font(.gsRegular(13)).foregroundStyle(Color.appTextSecondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(categoryTotals.enumerated()), id: \.offset) { idx, entry in
                        let (cat, words) = entry
                        let pct = Int((Double(words) / Double(total) * 100).rounded())
                        categoryRow(cat: cat, words: words, pct: pct,
                                    isTop: idx == 0,
                                    widthFraction: CGFloat(words) / CGFloat(maxWords))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCardStyle()
    }

    @ViewBuilder
    private func categoryRow(cat: AppCategory, words: Int, pct: Int, isTop: Bool, widthFraction: CGFloat) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.appGaugeTrack.opacity(0.7))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon(for: cat))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.figPeriwinkleMed)
                )
            if isTop {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.appGaugeTrack)
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.figPeriwinkleStrong)
                            .frame(width: max(60, geo.size.width * widthFraction))
                            .overlay(alignment: .leading) {
                                Text("\(pct)%")
                                    .font(.gsBold(13))
                                    .foregroundStyle(.white)
                                    .padding(.leading, 14)
                            }
                    }
                }
                .frame(height: 28)
                Text("\(bigNumber(words)) \(noun(for: cat))")
                    .font(.gsMedium(11))
                    .foregroundStyle(Color.appTextSecondary)
                    .tracking(0.5)
                    .fixedSize()
            } else {
                Text("\(pct)%")
                    .font(.gsBold(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.figPeriwinkleLight))
                Text("\(bigNumber(words)) \(noun(for: cat))")
                    .font(.gsMedium(11))
                    .foregroundStyle(Color.appTextSecondary)
                    .tracking(0.5)
                Spacer()
            }
        }
    }
}
