import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case dictation, notetaker, insights, dictionary, snippets, style, transforms, scratchpad
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var isActive: Bool { self == .dictation || self == .insights }
    var systemImage: String {
        switch self {
        case .dictation: "mic"; case .notetaker: "record.circle"
        case .insights: "chart.bar"; case .dictionary: "character.book.closed"
        case .snippets: "scissors"; case .style: "textformat"
        case .transforms: "wand.and.stars"; case .scratchpad: "note.text"
        }
    }
}

struct RootView: View {
    @State private var selection: Section = .dictation
    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { s in
                Label(s.title, systemImage: s.systemImage)
                    .foregroundStyle(s.isActive ? .primary : .secondary)
                    .tag(s)
            }
            .navigationTitle("Lotti")
        } detail: {
            switch selection {
            case .dictation: DictationView()
            case .insights: InsightsView()
            default: ContentUnavailableView("Coming soon", systemImage: "clock")
            }
        }
    }
}
