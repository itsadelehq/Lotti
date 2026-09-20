import SwiftUI

struct DictationView: View {
    @EnvironmentObject var store: Store
    @State private var bannerDismissed = false
    @State private var voiceProfileDismissed = false

    private var items: [Dictation] { store.all() }
    private var stats: Stats { store.stats(now: .now) }

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
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Welcome back, Adele")
                .font(.gsBold(AppFontSizes.screenTitle))
                .foregroundStyle(Color.appTextPrimary)

            if !bannerDismissed {
                promoBanner
            }

            Text("TODAY")
                .font(.gsMedium(12))
                .foregroundStyle(Color.appTextSecondary)
                .tracking(1)

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
        VStack(spacing: 0) {
            if items.isEmpty {
                Text("No dictations yet today.")
                    .font(.gsRegular(14))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    feedRow(item)
                    if index != items.count - 1 {
                        Divider().overlay(Color.appDivider)
                    }
                }
            }
        }
    }

    private func feedRow(_ item: Dictation) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(item.createdAt, style: .time)
                .font(.gsRegular(13))
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 70, alignment: .leading)
            Text(item.polishedText)
                .font(.gsRegular(14))
                .foregroundStyle(Color.appTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
    }

    private var rightRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                statRow(value: "\(stats.totalWords)", label: "total words")
                statRow(value: "\(stats.wpm)", label: "wpm")
                statRow(value: "\(stats.currentStreak)", label: "day streak")
            }
            .appCardStyle()

            if !voiceProfileDismissed {
                voiceProfileCard
            }
        }
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

    private var voiceProfileCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Voice Profile Unlocked!")
                    .font(.gsBold(15))
                    .foregroundStyle(Color.appTextPrimary)
                Text("Discover your unique insights")
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.appTextSecondary)
                Button("Create report") {}
                    .buttonStyle(.plain)
                    .font(.gsMedium(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.appOrange))
                    .padding(.top, 4)
            }
            .appCardStyle()

            Button {
                voiceProfileDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(6)
                    .background(Circle().fill(Color.appCardMuted))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }
}
