import SwiftUI

/// Sound-wave brand mark drawn in SwiftUI, matching `Branding/Icon.svg`
/// (three horizontal wavy strokes) since we can't render SVG directly.
struct BrandMark: View {
    var size: CGFloat = 22
    var color: Color = .appMarkBlack
    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            for i in 0..<3 {
                var path = Path()
                let y = h * (0.28 + Double(i) * 0.22)
                let amplitude = h * 0.16
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(
                    to: CGPoint(x: w * 0.5, y: y),
                    control1: CGPoint(x: w * 0.17, y: y - amplitude),
                    control2: CGPoint(x: w * 0.33, y: y + amplitude))
                path.addCurve(
                    to: CGPoint(x: w, y: y),
                    control1: CGPoint(x: w * 0.67, y: y - amplitude),
                    control2: CGPoint(x: w * 0.83, y: y + amplitude))
                // Heavier stroke so the mark reads as bold as the black app icon.
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: max(2.5, h * 0.11), lineCap: .round))
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

/// Sidebar brand header: mark + "Lotti" wordmark + "Pro" pill.
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            BrandMark(size: 16, color: .appMarkBlack)
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
