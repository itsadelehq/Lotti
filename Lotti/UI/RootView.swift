import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case dictation, notetaker, insights, dictionary, style, scratchpad, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var isActive: Bool { self == .dictation || self == .insights || self == .settings }
    var systemImage: String {
        switch self {
        case .dictation: "mic"; case .notetaker: "record.circle"
        case .insights: "chart.bar"; case .dictionary: "character.book.closed"
        case .style: "textformat"; case .scratchpad: "note.text"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @State private var selection: Section = .dictation
    private let mainSections: [Section] = [
        .dictation, .notetaker, .insights, .dictionary, .style, .scratchpad,
    ]

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                BrandHeader()
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                VStack(spacing: 2) {
                    ForEach(mainSections) { s in
                        sidebarRow(s)
                    }
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 0)

                Divider().padding(.horizontal, 12)
                VStack(spacing: 2) {
                    sidebarRow(.settings)
                        .padding(.horizontal, 8)
                    HStack {
                        Label("Help", systemImage: "questionmark.circle")
                            .font(.gsRegular(13))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .background(Color.appSidebarBg)
            .frame(minWidth: 230, idealWidth: 230)
        } detail: {
            Group {
                switch selection {
                case .dictation: DictationView()
                case .insights: InsightsView()
                case .settings: SettingsView()
                default: ContentUnavailableView("Coming soon", systemImage: "clock")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appPanel)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
        }
        .background(Color.appBg)
        .background(WindowAccessor())
        .onAppear { AppFonts.register() }
    }

    @ViewBuilder
    private func sidebarRow(_ s: Section) -> some View {
        HStack(spacing: 12) {
            Image(systemName: s.systemImage)
                .font(.system(size: 20))
                .frame(width: 20)
            Text(s.title)
                .font(.gsMedium(17))
            Spacer()
        }
        .foregroundStyle(selection == s ? Color.appTextPrimary : Color(hex: 0x3A3A38))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 42)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selection == s ? Color(hex: 0xECEBE6) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selection = s }
    }
}
