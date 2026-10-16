import SwiftUI
import AppKit
import WebKit
import CoreImage

struct DictationView: View {
    @EnvironmentObject var store: Store
    // Persists across navigation: stores the date-key ("2026-09-21") of the
    // day the banner was dismissed, so it stays hidden for the rest of that
    // calendar day but reappears (with a new quote) on the next day.
    @AppStorage("quoteBannerDismissedDay") private var quoteBannerDismissedDay = ""
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
        // doesn't change the count — or a save that happens while this view is
        // already on screen — still triggers a refresh.
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

            if quoteBannerDismissedDay != Self.todayKey {
                quoteBanner
            }

            feed
        }
    }

    // MARK: - Daily motivational quote banner

    /// Date key like "2026-09-21", used both for the once-per-day quote
    /// index and for the dismissal persistence check above.
    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    /// Deterministic by calendar day: day-of-year mod the quote count, so the
    /// same quote shows all day and rotates the next day.
    private static var todaysQuote: MotivationalQuote {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let index = dayOfYear % motivationalQuotes.count
        return motivationalQuotes[index]
    }

    /// Same day-of-year source as `todaysQuote`, so the ShaderGradient
    /// background rotates in lockstep with the quote — both change together
    /// once a day.
    private static var todaysShaderPreset: ShaderPreset {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let index = dayOfYear % shaderPresets.count
        return shaderPresets[index]
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
                        Text("— \(Self.todaysQuote.author)")
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
                quoteBannerDismissedDay = Self.todayKey
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
                    Text("No dictations yet — hold your key and speak to get started.")
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
                .font(.loraRegular(27))
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

/// One ShaderGradient color/type configuration for the quote banner
/// background. Colors are hex strings without the leading `#` (the shader
/// HTML page adds it back).
struct ShaderPreset {
    let c1: String
    let c2: String
    let c3: String
    let type: String

    /// Stable identity used by `ShaderGradientView` to decide whether the
    /// embedded web view needs to reload for a new preset.
    var key: String { "\(c1)-\(c2)-\(c3)-\(type)" }
}

/// The rotating set of ShaderGradient presets for the daily quote banner.
/// One is picked deterministically per calendar day (see
/// `DictationView.todaysShaderPreset`), in lockstep with the daily quote.
/// Add more presets here — one line each — to extend the rotation.
let shaderPresets: [ShaderPreset] = [
    // Curated, on-brand set — warm/teal/periwinkle tones that read well
    // behind white serif text with the dark scrim.
    .init(c1: "0E5A4F", c2: "5FB7A6", c3: "B6BEFF", type: "plane"),      // teal → periwinkle
    .init(c1: "E29B7B", c2: "C77FA6", c3: "9AA6E8", type: "waterPlane"), // sunset → violet
    .init(c1: "4D6FD1", c2: "6A7EFF", c3: "C7B8F5", type: "plane"),      // indigo → lilac
    .init(c1: "C98F7A", c2: "7FB0C4", c3: "B6BEFF", type: "waterPlane")  // clay → sky
]

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
    .init(text: "Your voice is your instrument — use it deliberately.", author: "Unknown"),
    .init(text: "Momentum builds one honest sentence at a time.", author: "Unknown"),
    .init(text: "You have to be aggressive for the life that you want."),
    .init(text: "Become the person you want to become."),
    .init(text: "The cost of discipline is that every day looks the same; the cost of indiscipline is that every year looks the same."),
]

/// Low-opacity procedural noise that sits over the gradient so the banner
/// reads as a grainy photograph rather than a flat fill, even before a real
/// texture image is dropped in.
/// One blurred colour blob, in fractions of the banner size, recreating the
/// reference design spec. `amp*`/`speed`/`phase` drive a continuous sine-based
/// drift so the composition always flows.
private struct BlobSpec {
    let x, y, w, h: Double            // fractions of banner width/height
    let stops: [Gradient.Stop]
    let blurVW: Double                // blur as % of banner width
    let opacity: Double
    let ampX, ampY: Double            // drift amplitude (fractions of w/h)
    let speed: Double
    let phase: Double
}

private func gstop(_ hex: String, _ loc: Double, _ a: Double = 1) -> Gradient.Stop {
    .init(color: Color(hexString: hex, alpha: a), location: loc)
}

private let blobSpecs: [BlobSpec] = [
    .init(x: -0.09, y: -0.15, w: 0.365, h: 0.945,
          stops: [gstop("D39B87", 0), gstop("DF7139", 0.35), gstop("DC7541", 0.65), gstop("D49BA7", 1)],
          blurVW: 2.1, opacity: 1, ampX: 0.06, ampY: 0.05, speed: 0.62, phase: 0),
    .init(x: 0.79, y: -0.075, w: 0.41, h: 1.20,
          stops: [gstop("E3CCCA", 0), gstop("E7AF94", 0.25), gstop("E7A181", 0.53), gstop("E8A58D", 1)],
          blurVW: 3.8, opacity: 1, ampX: 0.07, ampY: 0.04, speed: 0.46, phase: 1.1),
    .init(x: 0.175, y: 0.457, w: 0.15, h: 0.697,
          stops: [gstop("BC9FC8", 0), gstop("A49BD7", 0.5), gstop("8884DA", 1)],
          blurVW: 3.0, opacity: 0.78, ampX: 0.08, ampY: 0.09, speed: 0.74, phase: 2.0),
    .init(x: 0.24, y: -0.1125, w: 0.63, h: 1.237,
          stops: [gstop("8B87DC", 0), gstop("606AE2", 0.26), gstop("4C5CE2", 0.48), gstop("4C5BE5", 0.73), gstop("4E5EE5", 1)],
          blurVW: 2.1, opacity: 1, ampX: 0.05, ampY: 0.05, speed: 0.52, phase: 3.3),
    .init(x: 0.4075, y: -0.12, w: 0.35, h: 1.147,
          stops: [gstop("D8C6DB", 0), gstop("DCC9DA", 0.35), gstop("D9C2D5", 0.52), gstop("D9C2D5", 0.70, 0.44), gstop("C1AFD7", 0.85, 0), gstop("C1AFD7", 1, 0)],
          blurVW: 1.5, opacity: 1, ampX: 0.07, ampY: 0.04, speed: 0.68, phase: 0.6),
    .init(x: 0.53, y: -0.1275, w: 0.30, h: 1.237,
          stops: [gstop("7F7BD8", 0), gstop("8A80DA", 0.32), gstop("7F77D6", 0.57), gstop("6A68DB", 0.80), gstop("6E6BE0", 1)],
          blurVW: 1.5, opacity: 1, ampX: 0.06, ampY: 0.05, speed: 0.58, phase: 4.2),
    .init(x: 0.66, y: -0.1275, w: 0.23, h: 1.275,
          stops: [gstop("D9C6D7", 0), gstop("E2CED9", 0.35), gstop("E6D0D7", 0.65), gstop("E5CCCF", 1)],
          blurVW: 1.5, opacity: 1, ampX: 0.06, ampY: 0.05, speed: 0.5, phase: 5.0),
    .init(x: 0.815, y: 0.45, w: 0.10, h: 0.705,
          stops: [gstop("C6B7D8", 0), gstop("A49AD7", 0.35), gstop("8B83D4", 0.70), gstop("9389D5", 1)],
          blurVW: 1.5, opacity: 0.88, ampX: 0.09, ampY: 0.08, speed: 0.8, phase: 1.7),
]

/// Native animated recreation of the reference gradient. A `TimelineView`
/// drives continuous sine-based drift of each blurred blob, so it flows the
/// whole time the window is visible (no WebView, no focus/occlusion pausing).
private struct BlobGradient: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let W = geo.size.width, H = geo.size.height
                ZStack(alignment: .topLeading) {
                    Color(hexString: "E8D5D4")
                    LinearGradient(gradient: Gradient(stops: [
                        gstop("DCCCD9", 0), gstop("D9C4D7", 0.45), gstop("D3ACC3", 1),
                    ]), startPoint: .leading, endPoint: .trailing)

                    ForEach(blobSpecs.indices, id: \.self) { i in
                        let b = blobSpecs[i]
                        let dx = sin(t * b.speed + b.phase) * b.ampX * W
                        let dy = cos(t * b.speed * 0.9 + b.phase) * b.ampY * H
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(stops: b.stops),
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: b.w * W, height: b.h * H)
                            .blur(radius: b.blurVW / 100 * W)
                            .opacity(b.opacity)
                            .offset(x: b.x * W + dx, y: b.y * H + dy)
                    }
                }
                .frame(width: W, height: H)
                .saturation(1.45)
                .brightness(0.02)
                .contrast(1.03)
                .overlay(
                    // Fine film grain that SHIMMERS (cycles noise frames ~14/s)
                    // so it reads as real grain and moves with the gradient,
                    // instead of a frozen speckle layer.
                    Image(nsImage: GrainTiles.tiles[Int(t * 14) % GrainTiles.tiles.count])
                        .resizable(resizingMode: .tile)
                        .blendMode(.overlay)
                        .opacity(0.55)
                        .allowsHitTesting(false)
                )
                .clipped()
            }
        }
    }
}

/// Pre-rendered fine film-grain tiles (grayscale Core Image noise). The banner
/// cycles through them over time for a shimmering grain that moves with the
/// flowing gradient. Generated once and cached.
private enum GrainTiles {
    static let tiles: [NSImage] = (0..<10).map { make(shift: CGFloat($0) * 211 + 7) }
    private static let ctx = CIContext(options: [.useSoftwareRenderer: false])
    private static func make(shift: CGFloat) -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let rect = CGRect(origin: .zero, size: size)
        guard let gen = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return NSImage(size: size)
        }
        // Grayscale, slightly boosted contrast; sample a different region per
        // tile so each frame's noise is distinct (→ shimmer when cycled).
        let mono = gen
            .applyingFilter("CIColorControls",
                            parameters: [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 1.15])
            .transformed(by: CGAffineTransform(translationX: shift, y: shift * 1.7))
        guard let cg = ctx.createCGImage(mono, from: rect) else { return NSImage(size: size) }
        return NSImage(cgImage: cg, size: size)
    }
}

/// Deterministic RNG so the grain pattern is stable across redraws instead of
/// re-randomizing (and visibly shimmering) on every SwiftUI update pass.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// A single dictation row that reveals a trailing action cluster on hover.
private struct FeedRow: View {
    let item: Dictation
    var onDelete: () -> Void = {}

    @EnvironmentObject var store: Store
    @State private var hovering = false
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
            // the row is hovered — reserving the space avoids any reflow jump.
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
        HStack(spacing: 10) {
            iconButton(copied ? "checkmark" : "doc.on.doc", help: copied ? "Copied!" : "Copy transcript") {
                copy()
            }
            iconButton("flag", help: "Flag") {}
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.figTextGrey)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More options")
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.figTextGrey)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
