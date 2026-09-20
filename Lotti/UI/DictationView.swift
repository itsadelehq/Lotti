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
            HStack(alignment: .top, spacing: 24) {
                mainColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                rightRail
                    .frame(width: 320)
            }
            .padding(28)
        }
        .task { refreshIfNeeded() }
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Welcome back, Adele")
                .font(.gsBold(AppFontSizes.screenTitle))
                .foregroundStyle(Color.appTextPrimary)

            if !bannerDismissed {
                promoBanner
            }

            feed
        }
    }

    private var promoBanner: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Working around other people?")
                    .font(.gsBold(20))
                    .foregroundStyle(.white)
                Text("Learn how to dictate discreetly, even in shared spaces.")
                    .font(.gsRegular(14))
                    .foregroundStyle(.white.opacity(0.7))
                Button("Show me how") {}
                    .buttonStyle(.plain)
                    .font(.gsMedium(13))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white))
                    .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.appPillBlack))

            Button {
                bannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(8)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .padding(14)
        }
    }

    private var feed: some View {
        VStack(alignment: .leading, spacing: 18) {
            if dayGroups.isEmpty {
                sectionHeader("TODAY")
                Text("No dictations yet today.")
                    .font(.gsRegular(14))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                ForEach(dayGroups) { group in
                    sectionHeader(group.title)
                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            FeedRow(item: item)
                            if index != group.items.count - 1 {
                                Divider().overlay(Color.appDivider)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.gsMedium(12))
                .foregroundStyle(Color.appTextSecondary)
                .tracking(1)
            Spacer()
            if title == "TODAY" {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private var rightRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            statRow(value: "\(stats.totalWords)", label: "total words")
            statRow(value: "\(stats.wpm)", label: "wpm")
            statRow(value: "\(stats.currentStreak)", label: "day streak")
        }
        .appCardStyle()
    }

    private func statRow(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.gsBold(30))
                .foregroundStyle(Color.appTextPrimary)
            Text(label)
                .font(.gsRegular(13))
                .foregroundStyle(Color.appTextSecondary)
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
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 70, alignment: .leading)
            Text(item.polishedText)
                .font(.gsRegular(14))
                .foregroundStyle(Color.appTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            actions
                .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 14)
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
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
