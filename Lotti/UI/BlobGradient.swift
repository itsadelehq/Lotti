import SwiftUI
import AppKit
import CoreImage

/// One blurred colour blob, in fractions of the banner size, recreating the
/// reference design spec. `amp*`/`speed`/`phase` drive a continuous sine-based
/// drift so the composition always flows.
struct BlobSpec {
    let x, y, w, h: Double            // fractions of banner width/height
    let stops: [Gradient.Stop]
    let blurVW: Double                // blur as % of banner width
    let opacity: Double
    let ampX, ampY: Double            // drift amplitude (fractions of w/h)
    let speed: Double
    let phase: Double
}

func gstop(_ hex: String, _ loc: Double, _ a: Double = 1) -> Gradient.Stop {
    .init(color: Color(hexString: hex, alpha: a), location: loc)
}

/// A colour scheme for `BlobGradient`: a base wash plus the per-blob fills.
/// The blob GEOMETRY/motion is shared across palettes, only the colours
/// differ, so every palette keeps the same soft, flowing composition.
struct BlobPalette {
    let bg: String
    let base: [Gradient.Stop]
    let specs: [BlobSpec]
}

/// Shared blob geometry + motion. A palette supplies colours for each slot.
private func blobGeometry(_ stops: [[Gradient.Stop]]) -> [BlobSpec] {
    let g: [(Double, Double, Double, Double, Double, Double, Double, Double, Double, Double)] = [
        (-0.09,  -0.15,   0.365, 0.945, 2.1, 1.0,  0.06, 0.05, 0.62, 0.0),
        ( 0.79,  -0.075,  0.41,  1.20,  3.8, 1.0,  0.07, 0.04, 0.46, 1.1),
        ( 0.175,  0.457,  0.15,  0.697, 3.0, 0.78, 0.08, 0.09, 0.74, 2.0),
        ( 0.24,  -0.1125, 0.63,  1.237, 2.1, 1.0,  0.05, 0.05, 0.52, 3.3),
        ( 0.4075,-0.12,   0.35,  1.147, 1.5, 1.0,  0.07, 0.04, 0.68, 0.6),
        ( 0.53,  -0.1275, 0.30,  1.237, 1.5, 1.0,  0.06, 0.05, 0.58, 4.2),
        ( 0.66,  -0.1275, 0.23,  1.275, 1.5, 1.0,  0.06, 0.05, 0.50, 5.0),
        ( 0.815,  0.45,   0.10,  0.705, 1.5, 0.88, 0.09, 0.08, 0.80, 1.7),
    ]
    return zip(g, stops).map { geo, s in
        BlobSpec(x: geo.0, y: geo.1, w: geo.2, h: geo.3, stops: s,
                 blurVW: geo.4, opacity: geo.5,
                 ampX: geo.6, ampY: geo.7, speed: geo.8, phase: geo.9)
    }
}

extension BlobPalette {
    /// Warm orange → cornflower blue → lavender (the Dictation quote banner).
    static let sunset = BlobPalette(
        bg: "E8D5D4",
        base: [gstop("DCCCD9", 0), gstop("D9C4D7", 0.45), gstop("D3ACC3", 1)],
        specs: blobGeometry([
            [gstop("D39B87", 0), gstop("DF7139", 0.35), gstop("DC7541", 0.65), gstop("D49BA7", 1)],
            [gstop("E3CCCA", 0), gstop("E7AF94", 0.25), gstop("E7A181", 0.53), gstop("E8A58D", 1)],
            [gstop("BC9FC8", 0), gstop("A49BD7", 0.5), gstop("8884DA", 1)],
            [gstop("8B87DC", 0), gstop("606AE2", 0.26), gstop("4C5CE2", 0.48), gstop("4C5BE5", 0.73), gstop("4E5EE5", 1)],
            [gstop("D8C6DB", 0), gstop("DCC9DA", 0.35), gstop("D9C2D5", 0.52), gstop("D9C2D5", 0.70, 0.44), gstop("C1AFD7", 0.85, 0), gstop("C1AFD7", 1, 0)],
            [gstop("7F7BD8", 0), gstop("8A80DA", 0.32), gstop("7F77D6", 0.57), gstop("6A68DB", 0.80), gstop("6E6BE0", 1)],
            [gstop("D9C6D7", 0), gstop("E2CED9", 0.35), gstop("E6D0D7", 0.65), gstop("E5CCCF", 1)],
            [gstop("C6B7D8", 0), gstop("A49AD7", 0.35), gstop("8B83D4", 0.70), gstop("9389D5", 1)],
        ]))

    /// Periwinkle → lavender → butter yellow (the Insights hero), matching the
    /// Insights page's periwinkle charts and butter-yellow accent chip.
    static let iris = BlobPalette(
        bg: "EDECF6",
        base: [gstop("DCDEF2", 0), gstop("DFE0EC", 0.45), gstop("EFEAC6", 1)],
        specs: blobGeometry([
            [gstop("9AA6FF", 0), gstop("6A7EFF", 0.35), gstop("4D5FE0", 0.65), gstop("9AA6FF", 1)],
            [gstop("F8EDBE", 0), gstop("F3E29A", 0.30), gstop("E9D278", 0.60), gstop("F8EDBE", 1)],
            [gstop("9AA6FF", 0), gstop("6A7EFF", 0.5), gstop("4D5FE0", 1)],
            [gstop("7E8CFF", 0), gstop("4D5FE0", 0.30), gstop("6A7EFF", 0.60), gstop("9AA6FF", 1)],
            [gstop("DEE1FA", 0), gstop("C7CBF5", 0.40), gstop("C7CBF5", 0.70, 0.4), gstop("C7CBF5", 1, 0)],
            [gstop("DEE1FA", 0), gstop("E6E2C0", 0.5), gstop("F3E29A", 1)],
            [gstop("F8EDBE", 0), gstop("F3EFE6", 0.5), gstop("F6E8B0", 1)],
            [gstop("F3E29A", 0), gstop("E9D278", 0.5), gstop("DCC45E", 1)],
        ]))

    /// Teal → mint/aqua → coral (the Scratchpad hero).
    static let lagoon = BlobPalette(
        bg: "CBE6DA",
        base: [gstop("CBE6DA", 0), gstop("C8E3DF", 0.45), gstop("E8D2C6", 1)],
        specs: blobGeometry([
            [gstop("5BB9A9", 0), gstop("2E9E8D", 0.35), gstop("1F7E70", 0.65), gstop("5BB9A9", 1)],
            [gstop("F0BFAE", 0), gstop("E89E86", 0.30), gstop("D97E66", 0.60), gstop("F0BFAE", 1)],
            [gstop("5BB9A9", 0), gstop("2E9E8D", 0.5), gstop("1F7E70", 1)],
            [gstop("3DAE9C", 0), gstop("1F7E70", 0.30), gstop("2E9E8D", 0.60), gstop("5BB9A9", 1)],
            [gstop("DCEEDF", 0), gstop("C3E3CE", 0.40), gstop("C3E3CE", 0.70, 0.4), gstop("C3E3CE", 1, 0)],
            [gstop("C3E3EA", 0), gstop("9AD2DE", 0.45), gstop("7BBECD", 1)],
            [gstop("DCEEDF", 0), gstop("E8F0E6", 0.5), gstop("F0E6D8", 1)],
            [gstop("E89E86", 0), gstop("D97E66", 0.5), gstop("C96A52", 1)],
        ]))

    /// Dusty rose → warm sand (the Snippets promo card).
    static let blush = BlobPalette(
        bg: "F2E6D4",
        base: [gstop("E9B7C0", 0), gstop("EAC9BE", 0.45), gstop("F0D6B2", 1)],
        specs: blobGeometry([
            [gstop("E6A2AF", 0), gstop("DB7E91", 0.35), gstop("C96B80", 0.65), gstop("E6A2AF", 1)],
            [gstop("F7E7CF", 0), gstop("F0D5B1", 0.30), gstop("E7C599", 0.60), gstop("F3DFC0", 1)],
            [gstop("E6A2AF", 0), gstop("DB7E91", 0.5), gstop("C96B80", 1)],
            [gstop("DF8597", 0), gstop("C96B80", 0.30), gstop("D4738A", 0.60), gstop("E29CAA", 1)],
            [gstop("F7E7CF", 0), gstop("F0D5B1", 0.40), gstop("F0D5B1", 0.70, 0.4), gstop("F0D5B1", 1, 0)],
            [gstop("F7E7CF", 0), gstop("F0D5B1", 0.45), gstop("E7C599", 1)],
            [gstop("F7E7CF", 0), gstop("F4E7D6", 0.5), gstop("F2E0C4", 1)],
            [gstop("F0D5B1", 0), gstop("E7C599", 0.5), gstop("DEB783", 1)],
        ]))

    /// Periwinkle → sage → pale yellow → burnt orange (the Notetaker banner).
    static let meadow = BlobPalette(
        bg: "E3EAD0",
        base: [gstop("E3EAD0", 0), gstop("DDE6C6", 0.45), gstop("E9E0BE", 1)],
        specs: blobGeometry([
            [gstop("A49FE0", 0), gstop("8984CF", 0.35), gstop("6E68C2", 0.65), gstop("A49FE0", 1)],
            [gstop("E07C4E", 0), gstop("CC5F38", 0.30), gstop("B8502E", 0.60), gstop("E07C4E", 1)],
            [gstop("A49FE0", 0), gstop("8984CF", 0.5), gstop("6E68C2", 1)],
            [gstop("9A94DA", 0), gstop("7E78C8", 0.30), gstop("6E68C2", 0.60), gstop("9A94DA", 1)],
            [gstop("E3EAD0", 0), gstop("D4DFBB", 0.40), gstop("D4DFBB", 0.70, 0.4), gstop("D4DFBB", 1, 0)],
            [gstop("EFE7A6", 0), gstop("E6D98A", 0.45), gstop("DCCB6A", 1)],
            [gstop("EFE7A6", 0), gstop("E3EAD0", 0.5), gstop("F0E8C0", 1)],
            [gstop("E07C4E", 0), gstop("CC5F38", 0.5), gstop("B8502E", 1)],
        ]))
}

/// Native animated recreation of the reference gradient. A `TimelineView`
/// drives continuous sine-based drift of each blurred blob, so it flows the
/// whole time the window is visible (no WebView, no focus/occlusion pausing).
/// `palette` picks the colour scheme; geometry/motion are shared.
struct BlobGradient: View {
    var palette: BlobPalette = .sunset
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let W = geo.size.width, H = geo.size.height
                ZStack(alignment: .topLeading) {
                    Color(hexString: palette.bg)
                    LinearGradient(gradient: Gradient(stops: palette.base),
                                   startPoint: .leading, endPoint: .trailing)

                    ForEach(palette.specs.indices, id: \.self) { i in
                        let b = palette.specs[i]
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
                .saturation(1.28)
                .contrast(1.0)
                .overlay(
                    // STILL fine film grain (no shimmer) so it reads as texture
                    // and is easy on the eyes while the colours flow underneath.
                    Image(nsImage: GrainTiles.still)
                        .resizable(resizingMode: .tile)
                        .blendMode(.overlay)
                        .opacity(0.3)
                        .allowsHitTesting(false)
                )
                .clipped()
            }
        }
    }
}

/// Small circular "×" shown at the top-trailing of a gradient hero banner so
/// the user can dismiss it (matches the Dictation quote banner's dismiss).
struct BannerDismissButton: View {
    var action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.black.opacity(hovering ? 0.55 : 0.4)))
        }
        .buttonStyle(.plain)
        .padding(14)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help("Hide banner")
    }
}

/// A pre-rendered, cached fine film-grain tile (grayscale Core Image noise),
/// shown static behind the flowing gradient.
private enum GrainTiles {
    static let still: NSImage = make(shift: 7)
    private static let ctx = CIContext(options: [.useSoftwareRenderer: false])
    private static func make(shift: CGFloat) -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let rect = CGRect(origin: .zero, size: size)
        guard let gen = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return NSImage(size: size)
        }
        let mono = gen
            .applyingFilter("CIColorControls",
                            parameters: [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 0.9])
            .transformed(by: CGAffineTransform(translationX: shift, y: shift * 1.7))
        guard let cg = ctx.createCGImage(mono, from: rect) else { return NSImage(size: size) }
        return NSImage(cgImage: cg, size: size)
    }
}
