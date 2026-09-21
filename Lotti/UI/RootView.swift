import SwiftUI
import AppKit

/// Walks up to the enclosing `NSSplitView` that `NavigationSplitView` is built
/// on and suppresses the divider between the sidebar and the detail pane, so the
/// cream sidebar meets the cream gap with no hairline seam.
struct SplitViewDividerHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { hideDivider(from: v) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { hideDivider(from: nsView) }
    }
    private func hideDivider(from view: NSView) {
        var node: NSView? = view
        while let n = node {
            if let split = n as? NSSplitView {
                split.dividerStyle = .thin
                Self.makeDividerColorMatchBackground(on: split)
                break
            }
            node = n.superview
        }
    }

    /// `dividerStyle = .thin` alone still paints a 1pt hairline in the
    /// system's default divider color, which shows as a hard seam between the
    /// cream sidebar and the white panel. Since NavigationSplitView owns the
    /// actual NSSplitView instance (and its concrete runtime class), we can't
    /// subclass it ourselves — instead we swap just the `dividerColor` getter
    /// implementation on that runtime class to always return the cream
    /// background color, so the divider blends in and reads as no seam at all.
    private static var patchedClasses = Set<ObjectIdentifier>()
    private static func makeDividerColorMatchBackground(on split: NSSplitView) {
        let cls: AnyClass = type(of: split)
        let key = ObjectIdentifier(cls)
        guard !patchedClasses.contains(key) else { return }
        guard let method = class_getInstanceMethod(cls, #selector(getter: NSSplitView.dividerColor)) else { return }
        patchedClasses.insert(key)
        let block: @convention(block) (NSSplitView) -> NSColor = { _ in Color.appBgNS }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }
}

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
                    sidebarRow(.settings)
                    navRow(icon: "questionmark.circle", title: "Help", isActive: false) {}
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minWidth: 208, idealWidth: 208, maxWidth: 208)
            .navigationSplitViewColumnWidth(208)
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
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.appPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.figBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            // Cream gap on every side, including the leading edge, so there is a
            // clean band of #F5F4F1 between the (seamless) sidebar and the panel.
            .padding(.top, 10)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
            .background(Color.appBg)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Color.appBg)
        .background(SplitViewDividerHider())
        .background(WindowAccessor())
        .onAppear { AppFonts.register() }
    }

    @ViewBuilder
    private func sidebarRow(_ s: Section) -> some View {
        navRow(icon: s.systemImage, title: s.title, isActive: selection == s) {
            selection = s
        }
    }

    /// Shared 40pt nav row: 18pt icon + label with 10pt gap, 12pt horizontal
    /// padding, radius 6. Active rows use semibold weight over the #EDEDE8 pill;
    /// inactive rows are medium weight over a transparent background.
    @ViewBuilder
    private func navRow(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
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
                .fill(isActive ? Color.figNavActiveBg : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}
