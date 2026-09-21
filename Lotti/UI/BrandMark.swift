import SwiftUI

/// App-icon brand mark: the black three-wave mark from `Assets.xcassets`,
/// matching the app icon exactly (rendered as an image, not hand-drawn).
struct BrandMark: View {
    var size: CGFloat = 22
    var body: some View {
        Image("LottiMark")
            .resizable()
            .scaledToFit()
            .frame(height: size)
    }
}

/// Sidebar brand header: mark + "Lotti" wordmark + "Pro" pill.
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            BrandMark(size: 24)
            Text("Lotti")
                .font(.gsBold(18))
                .foregroundStyle(Color.figTextPrimary)
            Text("Pro")
                .font(.gsBold(12))
                .foregroundStyle(.black)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.figProPillBg))
            Spacer(minLength: 0)
        }
    }
}
