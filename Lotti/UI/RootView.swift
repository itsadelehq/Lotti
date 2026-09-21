import SwiftUI
import AppKit

enum Section: String, CaseIterable, Identifiable {
    case dictation, notetaker, insights, snippets, scratchpad, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var isActive: Bool { self == .dictation || self == .insights || self == .snippets || self == .settings }
    var systemImage: String {
        switch self {
        case .dictation: "mic"; case .notetaker: "record.circle"
        case .insights: "chart.bar"; case .snippets: "text.badge.plus"
        case .scratchpad: "note.text"
        case .settings: "gearshape"
        }
    }
}

/// Root layout WITHOUT `NavigationSplitView`. macOS's split view inserts an
/// `NSVisualEffectView` "sidebar material" behind the sidebar column that
/// cannot be reliably neutralised from SwiftUI, and its selection/navigation
/// machinery introduced click lag. We instead own the whole layout: a plain
/// `HStack` of a custom cream sidebar and the white content panel, both on one
/// flat `#F5F4F1` surface, so there is no material, no seam, and screen
/// switching is a synchronous `@State` change (instant).
struct RootView: View {
    @State private var selection: Section = .dictation
    @State private var hoveredSection: String?
    @State private var showSettings = false
    private let mainSections: [Section] = [
        .dictation, .notetaker, .insights, .snippets, .scratchpad,
    ]

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sidebar
                detail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBg)

            if showSettings {
                settingsModal
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowAccessor())
        .onAppear { AppFonts.register() }
    }

    // MARK: - Settings modal (centered card over a dimmed scrim)

    private var settingsModal: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { showSettings = false }

            SettingsView(onClose: { showSettings = false })
                .frame(width: 960, height: 640)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.19), radius: 30, y: 16)
        }
    }

    // MARK: - Sidebar (flat cream, no material / vibrancy / border / shadow)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandHeader()
                .padding(.horizontal, 12)
                .padding(.top, 18)
                .padding(.bottom, 16)

            VStack(spacing: 2) {
                ForEach(mainSections) { s in
                    sidebarRow(s)
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            // Hairline divider before the utility rows.
            Rectangle()
                .fill(Color.figBorder)
                .frame(height: 0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            VStack(spacing: 2) {
                navRow(id: Section.settings.id, icon: Section.settings.systemImage,
                       title: Section.settings.title, isActive: showSettings) {
                    showSettings = true
                }
                navRow(id: "help", icon: "questionmark.circle", title: "Help", isActive: false) {}
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .frame(width: 208)
        .frame(maxHeight: .infinity)
        .background(Color.appBg)
    }

    // MARK: - Detail (white rounded panel, cream inset gap on all sides)

    private var detail: some View {
        Group {
            switch selection {
            case .dictation: DictationView()
            case .notetaker: NotetakerView()
            case .insights: InsightsView()
            case .snippets: SnippetsView()
            case .scratchpad: ScratchpadView()
            default: ContentUnavailableView("Coming soon", systemImage: "clock")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.figBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // Cream gap on every side, including the leading edge, so there is a
        // clean band of #F5F4F1 between the sidebar and the panel.
        .padding(.top, 10)
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.bottom, 10)
        .background(Color.appBg)
    }

    @ViewBuilder
    private func sidebarRow(_ s: Section) -> some View {
        navRow(id: s.id, icon: s.systemImage, title: s.title, isActive: selection == s) {
            // Synchronous, unanimated selection change — instantaneous.
            selection = s
        }
    }

    /// Shared 40pt nav row: 18pt icon + label with 10pt gap, 12pt horizontal
    /// padding, radius 6. Active rows use semibold weight over the #ECEBE6 pill;
    /// inactive rows are medium weight over a transparent background, and show
    /// a subtle lighter pill on pointer hover (like Wispr Flow).
    @ViewBuilder
    private func navRow(id: String, icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredSection == id
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 18)
                Text(title)
                    .font(isActive ? .gsSemibold(14) : .gsMedium(14))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive ? Color.figTextPrimary : Color.figTextGrey)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.figNavActiveBg : (isHovered ? Color.figNavHoverBg : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            hoveredSection = hovering ? id : (hoveredSection == id ? nil : hoveredSection)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
