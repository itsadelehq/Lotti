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
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                VStack(spacing: 2) {
                    ForEach(mainSections) { s in
                        sidebarRow(s)
                    }
                }
                .padding(.horizontal, 14)

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    sidebarRow(.settings)
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .frame(width: 20)
                        Text("Help")
                            .font(.gsMedium(17))
                        Spacer()
                    }
                    .foregroundStyle(Color(hex: 0x3A3A38))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
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
            // Subtle shadow so the white panel floats against the cream sidebar
            // without reading as a hard border line where they meet.
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            // Cream gap on every side, including the leading edge, so there is a
            // clean band of #F5F4F1 between the sidebar and the white panel.
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
