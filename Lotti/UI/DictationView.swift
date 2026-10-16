import SwiftUI
import AppKit
import WebKit

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

    /// Native grainy gradient background for the quote banner, recreating the
    /// reference look as layered, heavily-blurred colour blobs over a base
    /// gradient (faithful to the provided design spec), finished with film
    /// grain. No WebGL / CDN.
    private var quoteBannerBackground: some View {
        ZStack {
            BlobGradient()
            GrainOverlay(intensity: 1.4)
        }
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
/// One blurred colour blob in the banner composition, defined in the reference
/// design's 4096×2731 canvas space so it can be scaled to any banner size.
private struct BlobSpec {
    let rect: CGRect            // position/size in canvas space
    let stops: [Gradient.Stop] // vertical (top→bottom) fill
    let blur: CGFloat          // blur radius in canvas px
    let opacity: Double
    let drift: CGSize          // how far it slowly flows (canvas px)
    let duration: Double       // seconds for one drift cycle
}

private let blobCanvas = CGSize(width: 4096, height: 2731)

private func stop(_ hex: String, _ loc: Double, _ a: Double = 1) -> Gradient.Stop {
    .init(color: Color(hexString: hex, alpha: a), location: loc)
}

/// The reference gradient, recreated faithfully from the provided design spec:
/// a base wash plus eight heavily-blurred, overlapping gradient blobs.
private let blobSpecs: [BlobSpec] = [
    .init(rect: CGRect(x: -368.64, y: -409.60, width: 1495.04, height: 2580.48),
          stops: [stop("D39B87", 0), stop("DF7139", 0.35), stop("DC7541", 0.65), stop("D49BA7", 1)],
          blur: 65, opacity: 1, drift: CGSize(width: 90, height: 60), duration: 13),
    .init(rect: CGRect(x: 3235.84, y: -204.80, width: 1679.36, height: 3276.80),
          stops: [stop("E3CCCA", 0), stop("E7AF94", 0.25), stop("E7A181", 0.53), stop("E8A58D", 1)],
          blur: 120, opacity: 1, drift: CGSize(width: -110, height: 50), duration: 17),
    .init(rect: CGRect(x: 716.80, y: 1249.28, width: 614.40, height: 1904.64),
          stops: [stop("BC9FC8", 0), stop("A49BD7", 0.5), stop("8884DA", 1)],
          blur: 95, opacity: 0.75, drift: CGSize(width: 70, height: -80), duration: 15),
    .init(rect: CGRect(x: 983.04, y: -307.20, width: 2580.48, height: 3379.20),
          stops: [stop("8B87DC", 0), stop("606AE2", 0.26), stop("4C5CE2", 0.48), stop("4C5BE5", 0.73), stop("4E5EE5", 1)],
          blur: 65, opacity: 1, drift: CGSize(width: -80, height: 70), duration: 19),
    .init(rect: CGRect(x: 1669.12, y: -327.68, width: 1433.60, height: 3133.44),
          stops: [stop("D8C6DB", 0), stop("DCC9DA", 0.35), stop("D9C2D5", 0.52), stop("D9C2D5", 0.70, 0.44), stop("C1AFD7", 0.85, 0), stop("C1AFD7", 1, 0)],
          blur: 47, opacity: 1, drift: CGSize(width: 100, height: 40), duration: 14),
    .init(rect: CGRect(x: 2170.88, y: -348.16, width: 1228.80, height: 3379.20),
          stops: [stop("7F7BD8", 0), stop("8A80DA", 0.32), stop("7F77D6", 0.57), stop("6A68DB", 0.80), stop("6E6BE0", 1)],
          blur: 47, opacity: 1, drift: CGSize(width: -90, height: -50), duration: 16),
    .init(rect: CGRect(x: 2703.36, y: -348.16, width: 942.08, height: 3481.60),
          stops: [stop("D9C6D7", 0), stop("E2CED9", 0.35), stop("E6D0D7", 0.65), stop("E5CCCF", 1)],
          blur: 47, opacity: 1, drift: CGSize(width: 80, height: 60), duration: 18),
    .init(rect: CGRect(x: 3338.24, y: 1228.80, width: 409.60, height: 1925.12),
          stops: [stop("C6B7D8", 0), stop("A49AD7", 0.35), stop("8B83D4", 0.70), stop("9389D5", 1)],
          blur: 47, opacity: 0.85, drift: CGSize(width: -70, height: 80), duration: 15),
]

/// Animated recreation of the reference gradient: the blurred blobs slowly
/// drift (transform-only, so it stays smooth) for a gentle flowing motion,
/// like the previous animated banner.
private struct BlobGradient: View {
    @State private var flow = false
    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / blobCanvas.width
            let sy = geo.size.height / blobCanvas.height
            ZStack(alignment: .topLeading) {
                Color(hexString: "E8D5D4")
                LinearGradient(gradient: Gradient(stops: [
                    stop("DCCCD9", 0), stop("D9C4D7", 0.45), stop("D3ACC3", 1),
                ]), startPoint: .leading, endPoint: .trailing)

                ForEach(blobSpecs.indices, id: \.self) { i in
                    let b = blobSpecs[i]
                    let dx = (flow ? b.drift.width : 0)
                    let dy = (flow ? b.drift.height : 0)
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(stops: b.stops),
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: b.rect.width * sx, height: b.rect.height * sy)
                        .blur(radius: b.blur * sx)
                        .opacity(b.opacity)
                        .offset(x: (b.rect.minX + dx) * sx, y: (b.rect.minY + dy) * sy)
                        .animation(.easeInOut(duration: b.duration).repeatForever(autoreverses: true),
                                   value: flow)
                }

                // Reference's grey overlay (overlay blend) for a touch of contrast.
                Color(hexString: "808080").opacity(0.5).blendMode(.overlay)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .onAppear { flow = true }
    }
}

private struct GrainOverlay: View {
    /// Higher = grainier. The quote banner uses a strong value to match the
    /// film-grain look of the reference gradients.
    var intensity: Double = 1.0
    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 42)
            // Dense fine grain, with both light and dark specks so it reads like
            // real film grain rather than only sparkle.
            let speckCount = Int(size.width * size.height / 4 * intensity)
            for _ in 0..<speckCount {
                let x = CGFloat.random(in: 0..<size.width, using: &generator)
                let y = CGFloat.random(in: 0..<size.height, using: &generator)
                let light = Bool.random(using: &generator)
                let opacity = Double.random(in: 0.03...0.16, using: &generator)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect),
                             with: .color((light ? Color.white : Color.black).opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
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
