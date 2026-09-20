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
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Insights")
                .font(.gsBold(AppFontSizes.screenTitle))
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
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
