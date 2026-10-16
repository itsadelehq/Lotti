import SwiftUI
import AppKit

struct DictationView: View {
    @EnvironmentObject var store: Store
    // Session-only dismiss (consistent with the other pages): the banner comes
    // back on relaunch/navigation, and turning the Settings gradient toggle
    // back on re-shows it immediately (see `.onChange` below).
    @State private var bannerDismissed = false
    @AppStorage("showGradients") private var showGradients = true
    /// The user's own first name, set during onboarding / Settings. Empty until set.
    @AppStorage("firstName") private var firstName = ""

    // Cached once (and refreshed only when the feed size changes) instead of
    // being recomputed as `body` computed properties on every SwiftUI render
    // pass, so switching to/from this screen is instant.
    @State private var stats = Stats(totalWords: 0, wpm: 0, currentStreak: 0, longestStreak: 0)
    @State private var dayGroups: [DayGroup] = []
    @State private var cachedItemCount = -1
    @State private var cachedRevision = -1

    /// Groups the (already newest-first) feed by calendar day, preserving order.
    private struct DayGroup: Identifiable {
        let id: Date
        let title: String
        let items: [Dictation]
    }

    private static func dayGroups(for items: [Dictation]) -> [DayGroup] {
        let cal = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [Dictation]] = [:]
        for item in items {
            let day = cal.startOfDay(for: item.createdAt)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(item)
        }
        return order.map { day in
            DayGroup(id: day, title: header(for: day, cal: cal), items: buckets[day] ?? [])
        }
    }

    /// The feed only ever shows the most recent dictations (a real app shows
    /// recent items, not thousands), so we cap it. Stats are still computed
    /// over the full store.
    private static let feedCap = 60

    private func refreshIfNeeded() {
        // Cheap COUNT query first, so navigating to Dictation doesn't fetch
        // and materialise ~1700 objects just to check whether anything changed.
        // Keyed on `store.revision` (not just count) so an edit/delete that
        // doesn't change the count, or a save that happens while this view is
        // already on screen, still triggers a refresh.
        let count = store.count()
        guard count != cachedItemCount || store.revision != cachedRevision else { return }
        cachedItemCount = count
        cachedRevision = store.revision
        let all = store.all()
        // `all` is already newest-first; take only the most recent rows so the
        // feed renders a bounded number of views.
        dayGroups = Self.dayGroups(for: Array(all.prefix(Self.feedCap)))
        stats = store.stats(now: .now)
    }

    private static func header(for day: Date, cal: Calendar) -> String {
        if cal.isDateInToday(day) { return "TODAY" }
        if cal.isDateInYesterday(day) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: day).uppercased()
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 28) {
                mainColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                rightRail
                    .frame(width: 250)
            }
            .padding(32)
        }
        .task { refreshIfNeeded() }
        .onChange(of: store.revision) { _, _ in refreshIfNeeded() }
        .onChange(of: showGradients) { _, on in if on { bannerDismissed = false } }
    }

    /// "Welcome back, <name>" once a name is set, otherwise just "Welcome back".
    private var welcomeTitle: String {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Welcome back" : "Welcome back, \(name)"
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(welcomeTitle)
                .font(.gsBold(25))
                .foregroundStyle(Color.figTextPrimary)

            if showGradients && !bannerDismissed {
                quoteBanner
            }

            feed
        }
    }

    // MARK: - Daily motivational quote banner

    /// Deterministic by calendar day: day-of-year mod the quote count, so the
    /// same quote shows all day and rotates the next day.
    private static var todaysQuote: MotivationalQuote {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let index = dayOfYear % motivationalQuotes.count
        return motivationalQuotes[index]
    }

    private var quoteBanner: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                // Animated ShaderGradient (WebGL) background, only rendered
                // while the banner itself is visible, to save GPU.
                quoteBannerBackground

                // Dark scrim so the white serif quote stays legible over the
                // bright, high-contrast gradient. Bumped up from the original
                // 0.45 leading opacity because some rotating presets (e.g.
                // the light pink/blue waterPlane preset) are much lighter
                // than the original orange/lilac default.
                // Only a soft left vignette so the vivid gradient stays true to
                // the reference; the quote relies on a text shadow for contrast.
                LinearGradient(
                    colors: [.black.opacity(0.28), .clear],
                    startPoint: .leading,
                    endPoint: UnitPoint(x: 0.55, y: 0.5))

                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    Text("\u{201C}\(Self.todaysQuote.text)\u{201D}")
                        .font(.instrumentSerifItalic(30))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 7, y: 1)
                        .fixedSize(horizontal: false, vertical: true)
                    if !Self.todaysQuote.author.isEmpty {
                        Text(Self.todaysQuote.author)
                            .font(.gsRegular(13))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 5, y: 1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                bannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    /// Quote banner background: the reference gradient recreated natively as
    /// layered, blurred, continuously-drifting colour blobs. Native (not a
    /// WebView) so the motion keeps running whenever the window is visible —
    /// WKWebView pauses CSS animation when the app isn't frontmost.
    private var quoteBannerBackground: some View {
        BlobGradient()
    }

    // MARK: - Feed

    private var feed: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if dayGroups.isEmpty {
                sectionHeader("TODAY")
                feedContainer {
                    Text("Hold your key and speak to get started.")
                        .font(.gsRegular(14))
                        .foregroundStyle(Color.figTextGrey)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 17)
                        .padding(.horizontal, 15)
                }
            } else {
                ForEach(dayGroups) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(group.title)
                        feedContainer {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                FeedRow(item: item, onDelete: {
                                    cachedItemCount = -1
                                    refreshIfNeeded()
                                })
                                if index != group.items.count - 1 {
                                    Rectangle()
                                        .fill(Color.figBorder)
                                        .frame(height: 0.5)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Rounded, hairline-bordered container that wraps the bordered-row list.
    @ViewBuilder
    private func feedContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.figBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.gsMedium(11))
                .foregroundStyle(Color.figTextGrey)
                .tracking(1.2)
            if title == "TODAY" {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.figTextGrey)
            }
            Spacer()
        }
    }

    // MARK: - Right rail stats

    private var rightRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            statRow(value: Self.compact(stats.totalWords), label: "total words")
            statRow(value: "\(stats.wpm)", label: "wpm")
            statRow(value: "\(stats.currentStreak)", label: "day streak")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 25, leading: 24, bottom: 20, trailing: 24))
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.figCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.figBorder, lineWidth: 0.5)
        )
    }

    /// Compact word count like Wispr: 229757 -> "229.8K", 1_200_000 -> "1.2M".
    static func compact(_ n: Int) -> String {
        switch n {
        case 1_000_000...:
            return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(n) / 1_000)
        default:
            return "\(n)"
        }
    }

    private func statRow(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(.gsBold(27))
                .foregroundStyle(Color.figTextPrimary)
            Text(label)
                .font(.gsRegular(14))
                .foregroundStyle(Color.figTextPrimary)
        }
    }
}

/// A short, punchy motivational quote paired with its author.
struct MotivationalQuote {
    let text: String
    var author: String = ""
}

/// ~30 built-in quotes; the banner picks one deterministically per calendar day.
let motivationalQuotes: [MotivationalQuote] = [
    .init(text: "Done is better than perfect.", author: "Sheryl Sandberg"),
    .init(text: "Start where you are. Use what you have. Do what you can.", author: "Arthur Ashe"),
    .init(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
    .init(text: "Discipline is choosing between what you want now and what you want most.", author: "Abraham Lincoln"),
    .init(text: "You don't have to be great to start, but you have to start to be great.", author: "Zig Ziglar"),
    .init(text: "Small daily improvements are the key to staggering long-term results.", author: "James Clear"),
    .init(text: "Focus on being productive instead of busy.", author: "Tim Ferriss"),
    .init(text: "The way to get started is to quit talking and begin doing.", author: "Walt Disney"),
    .init(text: "Action is the foundational key to all success.", author: "Pablo Picasso"),
    .init(text: "Well done is better than well said.", author: "Benjamin Franklin"),
    .init(text: "What you do today can improve all your tomorrows.", author: "Ralph Marston"),
    .init(text: "Motivation is what gets you started. Habit is what keeps you going.", author: "Jim Ryun"),
    .init(text: "It always seems impossible until it's done.", author: "Nelson Mandela"),
    .init(text: "The future depends on what you do today.", author: "Mahatma Gandhi"),
    .init(text: "Simplicity is the ultimate sophistication.", author: "Leonardo da Vinci"),
    .init(text: "Quality is not an act, it is a habit.", author: "Aristotle"),
    .init(text: "Either you run the day, or the day runs you.", author: "Jim Rohn"),
    .init(text: "You miss 100% of the shots you don't take.", author: "Wayne Gretzky"),
    .init(text: "Progress, not perfection.", author: "Unknown"),
    .init(text: "The best time to plant a tree was 20 years ago. The second best time is now.", author: "Chinese Proverb"),
    .init(text: "Do the one thing you think you cannot do.", author: "Eleanor Roosevelt"),
    .init(text: "A year from now you may wish you had started today.", author: "Karen Lamb"),
    .init(text: "Energy and persistence conquer all things.", author: "Benjamin Franklin"),
    .init(text: "Don't watch the clock; do what it does. Keep going.", author: "Sam Levenson"),
    .init(text: "Success is the sum of small efforts repeated day in and day out.", author: "Robert Collier"),
    .init(text: "You are never too old to set another goal or dream a new dream.", author: "C.S. Lewis"),
    .init(text: "Write it down. Say it out loud. Make it real.", author: "Unknown"),
    .init(text: "Clarity comes from engagement, not thought.", author: "Marie Forleo"),
    .init(text: "Your voice is your instrument, so use it deliberately.", author: "Unknown"),
    .init(text: "Momentum builds one honest sentence at a time.", author: "Unknown"),
    .init(text: "You have to be aggressive for the life that you want."),
    .init(text: "Become the person you want to become."),
    .init(text: "The cost of discipline is that every day looks the same; the cost of indiscipline is that every year looks the same."),
]


/// A single dictation row that reveals a trailing action cluster on hover.
private struct FeedRow: View {
    let item: Dictation
    var onDelete: () -> Void = {}

    @EnvironmentObject var store: Store
    @State private var hovering = false
    @State private var menuHover = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(item.createdAt, style: .time)
                .font(.gsRegular(13))
                .foregroundStyle(Color.figTextGrey)
                .frame(width: 70, alignment: .leading)
            Text(item.polishedText)
                .font(.gsRegular(14))
                .foregroundStyle(Color.figTextPrimary)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            // The action cluster is a real trailing column (not an overlay), so
            // it always reserves its gutter and the text wraps BEFORE it instead
            // of running underneath the icons. It's just hidden (opacity 0) until
            // the row is hovered, reserving the space avoids any reflow jump.
            actions
                .opacity(hovering ? 1 : 0)
                .frame(width: 86, alignment: .trailing)
        }
        .padding(.vertical, 17)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color(hex: 0xF0EFEB) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var actions: some View {
        HStack(spacing: 4) {
            HoverIcon(symbol: copied ? "checkmark" : "doc.on.doc",
                      help: copied ? "Copied" : "Copy transcript") { copy() }
            HoverIcon(symbol: "flag", help: "Flag") {}
            moreOptionsMenu
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.polishedText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }

    private var moreOptionsMenu: some View {
        Menu {
            Button {
                // Undo AI edit: no-op for now.
            } label: {
                Label("Undo AI edit", systemImage: "arrow.uturn.backward")
            }
            Button {
                // Retry transcript: no-op for now.
            } label: {
                Label("Retry transcript", systemImage: "arrow.clockwise")
            }
            Button(role: .destructive) {
                store.delete(item)
                onDelete()
            } label: {
                Label("Delete transcript", systemImage: "trash")
            }
            Button {
                // Extract audio: no-op for now.
            } label: {
                Label("Extract audio", systemImage: "waveform")
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90)) // vertical three-dots
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(menuHover ? Color.figTextPrimary : Color.figTextGrey)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(menuHover ? Color.black.opacity(0.08) : .clear))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { h in
            menuHover = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help("More options")
    }
}

/// A feed-row action icon that highlights (darker icon + soft rounded fill) on
/// hover, matching the Wispr-style hover affordance.
private struct HoverIcon: View {
    let symbol: String
    var help: String
    var action: () -> Void = {}
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? Color.figTextPrimary : Color.figTextGrey)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(hovering ? Color.black.opacity(0.08) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help(help)
    }
}
