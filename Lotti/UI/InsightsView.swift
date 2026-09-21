import SwiftUI

enum InsightsTab: String, CaseIterable, Identifiable {
    case usage = "Your usage", voice = "Your voice", bests = "Personal bests"
    var id: String { rawValue }
}

struct InsightsView: View {
    @EnvironmentObject var store: Store
    @State private var tab: InsightsTab = .usage
    // Computed once when the screen first appears (not on every render), so
    // switching to/from Insights and between its tabs is instant. See
    // `InsightsSnapshot`.
    @State private var snapshot: InsightsSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                segmentedTabs
                if let snapshot {
                    switch tab {
                    case .usage: UsageTab(snapshot: snapshot)
                    case .voice: VoiceTab(snapshot: snapshot)
                    case .bests: BestsTab(snapshot: snapshot)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .task {
            if snapshot == nil {
                snapshot = InsightsSnapshot.compute(from: store, now: .now)
            }
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
                        .fill(active ? Color.appTextPrimary : .clear)
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
