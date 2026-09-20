import SwiftUI

enum InsightsTab: String, CaseIterable, Identifiable {
    case usage = "Your usage", voice = "Your voice", bests = "Personal bests"
    var id: String { rawValue }
}

struct InsightsView: View {
    @EnvironmentObject var store: Store
    @State private var tab: InsightsTab = .usage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                segmentedTabs
                switch tab {
                case .usage: UsageTab(store: store)
                case .voice: VoiceTab(store: store)
                case .bests: BestsTab(store: store)
                }
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background(Color.appBg)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Insights")
                .font(.gsBold(40))
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
            ShareBadge()
        }
    }

    private var segmentedTabs: some View {
        HStack(spacing: 28) {
            ForEach(InsightsTab.allCases) { t in
                let active = tab == t
                VStack(spacing: 6) {
                    Text(t.rawValue)
                        .font(active ? .gsBold(15) : .gsMedium(15))
                        .foregroundStyle(active ? Color.appTextPrimary : Color.appTextSecondary)
                    Rectangle()
                        .fill(active ? Color.appTeal : .clear)
                        .frame(height: 2)
                }
                .fixedSize()
                .contentShape(Rectangle())
                .onTapGesture { tab = t }
            }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appDivider).frame(height: 1)
        }
    }
}

/// Circular rotating "SHARE • SHARE •" badge with a centered up-arrow icon,
/// teal outline (decorative, matches reference).
private struct ShareBadge: View {
    @State private var angle: Double = 0
    private let text = "SHARE • SHARE • SHARE • "

    var body: some View {
        ZStack {
            Circle().stroke(Color.appTeal, lineWidth: 1.5).frame(width: 62, height: 62)
            CircularText(text: text, radius: 26)
                .foregroundStyle(Color.appTeal)
                .rotationEffect(.degrees(angle))
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appTeal)
        }
        .frame(width: 62, height: 62)
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}

private struct CircularText: View {
    let text: String
    let radius: CGFloat

    var body: some View {
        let chars = Array(text)
        ZStack {
            ForEach(0..<chars.count, id: \.self) { i in
                let step = 360.0 / Double(chars.count)
                Text(String(chars[i]))
                    .font(.gsBold(9))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(step * Double(i)))
            }
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}
