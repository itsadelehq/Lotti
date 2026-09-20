import SwiftUI

/// Sound-wave brand mark drawn in SwiftUI, matching `Branding/Icon.svg`
/// (three horizontal wavy strokes) since we can't render SVG directly.
struct BrandMark: View {
    var size: CGFloat = 22
    var color: Color = .appTeal
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
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: max(1.5, h * 0.06), lineCap: .round))
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

/// Sidebar brand header: mark + "Lotti" wordmark + "Pro" pill.
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            BrandMark(size: 16, color: .appTeal)
            Text("Lotti")
                .font(.gsBold(19))
                .foregroundStyle(Color.appTextPrimary)
            Text("Pro")
                .font(.gsMedium(11))
                .foregroundStyle(Color.appProText)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.appProBg))
        }
    }
}
