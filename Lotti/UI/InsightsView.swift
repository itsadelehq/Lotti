import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var store: Store
    // Computed once when the screen first appears (not on every render). See
    // `InsightsSnapshot`.
    @State private var snapshot: InsightsSnapshot?
    @State private var bannerDismissed = false
    @AppStorage("showGradients") private var showGradients = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if showGradients && !bannerDismissed { banner }
                if let snapshot {
                    UsageTab(snapshot: snapshot)
                }
            }
            .padding(32)
        }
        .task {
            if snapshot == nil {
                snapshot = InsightsSnapshot.compute(from: store, now: .now)
            }
        }
        .onChange(of: store.revision) { _, _ in
            snapshot = InsightsSnapshot.compute(from: store, now: .now)
        }
    }

    /// Small animated gradient hero, like the Notetaker banner.
    private var banner: some View {
        ZStack(alignment: .leading) {
            BlobGradient(palette: .iris)

            // Soft left vignette; text uses a shadow for contrast.
            LinearGradient(colors: [.black.opacity(0.3), .clear],
                           startPoint: .leading, endPoint: UnitPoint(x: 0.6, y: 0.5))
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your voice, by the numbers")
                    .font(.gsSemibold(22))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                Text("Words, speed, streaks, and how you dictate")
                    .font(.gsRegular(13.5))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.45), radius: 5, y: 1)
            }
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            BannerDismissButton { bannerDismissed = true }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Insights")
                .font(.gsBold(AppFontSizes.screenTitle))
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
        }
    }

}
