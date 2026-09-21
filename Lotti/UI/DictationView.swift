import SwiftUI
import AppKit

struct DictationView: View {
    @EnvironmentObject var store: Store
    @State private var bannerDismissed = false

    // Cached once (and refreshed only when the feed size changes) instead of
    // being recomputed as `body` computed properties on every SwiftUI render
    // pass, so switching to/from this screen is instant.
    @State private var stats = Stats(totalWords: 0, wpm: 0, currentStreak: 0, longestStreak: 0)
    @State private var dayGroups: [DayGroup] = []
    @State private var cachedItemCount = -1

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

    private func refreshIfNeeded() {
        let items = store.all()
        guard items.count != cachedItemCount else { return }
        cachedItemCount = items.count
        dayGroups = Self.dayGroups(for: items)
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
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Welcome back, Adele")
                .font(.gsBold(25))
                .foregroundStyle(Color.figTextPrimary)

            if !bannerDismissed {
                promoBanner
            }

            feed
        }
    }

    // MARK: - Promo banner

    private var promoBanner: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Working around other people?")
                    .font(.gsBold(25))
                    .foregroundStyle(.white)
                Text("With the right setup, you can Flow without disrupting your neighbours")
                    .font(.gsRegular(14))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                } label: {
                    Text("Show me how")
                        .font(.gsBold(13))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.figCardFill))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 181, alignment: .topLeading)
            .background(bannerBackground)
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

    /// Approximates the Figma's tinted-image look: a maroon base with a dark-teal
    /// overlay, blended as a diagonal gradient (no external image needed).
    private var bannerBackground: some View {
        ZStack {
            Color(hex: 0x803A45).opacity(0.5)
            LinearGradient(
                colors: [
                    Color(hex: 0x0A2630).opacity(0.85),
                    Color(hex: 0x803A45).opacity(0.5),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
            Color(hex: 0x0A2630).opacity(0.55)
        }
    }

    // MARK: - Feed

    private var feed: some View {
        VStack(alignment: .leading, spacing: 20) {
            if dayGroups.isEmpty {
                sectionHeader("TODAY")
                feedContainer {
                    Text("No dictations yet today.")
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
                                FeedRow(item: item)
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

/// A single dictation row that reveals a trailing action cluster on hover.
private struct FeedRow: View {
    let item: Dictation
    @State private var hovering = false

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
            actions
                .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 17)
        .padding(.horizontal, 15)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            iconButton("play") {}
            iconButton("doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.polishedText, forType: .string)
            }
            iconButton("flag") {}
            iconButton("ellipsis") {}
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.figTextGrey)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
