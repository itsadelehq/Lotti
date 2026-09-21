import SwiftUI
import AppKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static let appBg = Color(hex: 0xF5F4F1)
    static let appSidebarBg = Color(hex: 0xF5F4F1)
    static let appBgNS = NSColor(red: 0xF5 / 255, green: 0xF4 / 255, blue: 0xF1 / 255, alpha: 1)
    static let appCard = Color.white
    static let appPanel = Color.white
    static let appCardMuted = Color(hex: 0xF0EFEB)
    static let appTextPrimary = Color(hex: 0x1A1A1A)
    static let appTextSecondary = Color(hex: 0x8A8A82)
    static let appTeal = Color(hex: 0x0E5A4F)
    static let appMarkBlack = Color(hex: 0x111111)
    static let appTealDeep = Color(hex: 0x0B463D)
    static let appGreenChipBg = Color(hex: 0xD8F0DF)
    static let appGreenChipText = Color(hex: 0x1B7A4B)
    static let appOrange = Color(hex: 0xF6A93B)
    static let appPillBlack = Color(hex: 0x1B1B1D)
    static let appProBg = Color(hex: 0xEDE7FB)
    static let appProText = Color(hex: 0x6C4BD8)
    static let appHairline = Color.black.opacity(0.06)
    static let appDivider = Color.black.opacity(0.08)

    // Figma dictation/sidebar spec tokens (exact values from the export).
    static let figCardFill   = Color(hex: 0xF7F5F2) // stat card / button fill
    static let figBorder     = Color(hex: 0xE8E6DE) // 0.5pt hairline border
    static let figTextPrimary = Color(hex: 0x212120)
    static let figTextGrey    = Color(hex: 0x78786F)
    static let figNavActiveBg = Color(hex: 0xEDEDE8)
    // Non-active hover highlight: a touch darker/greyer warm grey at full opacity.
    static let figNavHoverBg  = Color(hex: 0xE4E3DE)
    static let figProPillBg   = Color(hex: 0xEBD6FF)

    // Insights-specific tokens (reference screenshot).
    static let appInsightCard = Color(hex: 0xEFEEE9)   // warm grey card fill
    static let appGaugeTrack = Color(hex: 0xE4E3DD)    // gauge / bar track

    /// Heatmap scale mixing teal + warm grey (empty→max).
    static let heatmapMixed: [Color] = [
        Color(hex: 0xE4E3DD), // empty / none (warm grey)
        Color(hex: 0xCFE8D8), // low
        Color(hex: 0x7FC9A3), // med
        Color(hex: 0x2E9E73), // high
        Color(hex: 0x0E5A4F), // max
    ]

    static let heatmapScale: [Color] = [
        Color(hex: 0xEBEAE4),
        Color(hex: 0xCDE8D6),
        Color(hex: 0x8FD3AB),
        Color(hex: 0x3FAE77),
        Color(hex: 0x0E5A4F),
    ]
}

struct AppCard: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appHairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func appCardStyle(padding: CGFloat = 20) -> some View {
        modifier(AppCard(padding: padding))
    }
}

/// Insights card: warm-grey fill, radius 20, generous padding, subtle shadow,
/// no heavy border (matches the reference screenshot).
struct InsightCard: ViewModifier {
    var padding: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appInsightCard)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, y: 3)
    }
}

extension View {
    func insightCardStyle(padding: CGFloat = 24) -> some View {
        modifier(InsightCard(padding: padding))
    }
}
