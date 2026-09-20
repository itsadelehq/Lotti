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
            VStack(alignment: .leading, spacing: 24) {
                header
                segmentedTabs
                switch tab {
                case .usage: UsageTab(store: store)
                case .voice: VoiceTab(store: store)
                case .bests: BestsTab(store: store)
                }
            }
            .padding(28)
        }
        .background(Color.appBg)
    }

    private var header: some View {
        HStack {
            Text("Insights")
                .font(.gsBold(34))
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.appTeal, lineWidth: 1)
                    .frame(width: 46, height: 46)
                Text("SHARE •")
                    .font(.gsMedium(7))
                    .foregroundStyle(Color.appTeal)
            }
        }
    }

    private var segmentedTabs: some View {
        HStack(spacing: 4) {
            ForEach(InsightsTab.allCases) { t in
                Text(t.rawValue)
                    .font(.gsMedium(13))
                    .foregroundStyle(tab == t ? Color.appTextPrimary : Color.appTextSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tab == t ? Color.white : .clear)
                    )
                    .onTapGesture { tab = t }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appCardMuted))
        .fixedSize()
    }
}
