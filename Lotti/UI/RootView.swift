import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case dictation, notetaker, insights, dictionary, snippets, style, transforms, scratchpad, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var isActive: Bool { self == .dictation || self == .insights || self == .settings }
    var systemImage: String {
        switch self {
        case .dictation: "mic"; case .notetaker: "record.circle"
        case .insights: "chart.bar"; case .dictionary: "character.book.closed"
        case .snippets: "scissors"; case .style: "textformat"
        case .transforms: "wand.and.stars"; case .scratchpad: "note.text"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @State private var selection: Section = .dictation
    private let mainSections: [Section] = [
        .dictation, .notetaker, .insights, .dictionary, .snippets, .style, .transforms, .scratchpad,
    ]

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                BrandHeader()
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                List(selection: $selection) {
                    ForEach(mainSections) { s in
                        sidebarRow(s).tag(s)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                Spacer(minLength: 0)

                Divider().padding(.horizontal, 12)
                VStack(spacing: 2) {
                    sidebarRow(.settings).tag(Section.settings)
                    HStack {
                        Label("Help", systemImage: "questionmark.circle")
                            .font(.gsRegular(13))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
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
            .background(Color.appBg)
        }
        .background(Color.appBg)
        .background(WindowAccessor())
        .onAppear { AppFonts.register() }
    }

    @ViewBuilder
    private func sidebarRow(_ s: Section) -> some View {
        HStack(spacing: 10) {
            Image(systemName: s.systemImage)
                .frame(width: 18)
            Text(s.title)
                .font(.gsMedium(13))
            Spacer()
        }
        .foregroundStyle(selection == s ? Color.appTextPrimary : Color.appTextSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selection == s ? Color(hex: 0xECEBE6) : .clear)
        )
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .onTapGesture { selection = s }
    }
}
