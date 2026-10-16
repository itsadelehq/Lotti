import SwiftUI
import AppKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Hex string without a leading `#` (e.g. "6A7EFF"). Falls back to black
    /// if the string isn't valid hex.
    init(hexString: String, alpha: Double = 1) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        self.init(hex: UInt32(cleaned, radix: 16) ?? 0, alpha: alpha)
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
    static let appInsightCard = Color(hex: 0xF7F5F2)   // card fill (Figma)
    static let appGaugeTrack = Color(hex: 0xE4E3DD)    // gauge / bar track

    // Four-level graduated periwinkle Insights palette (from Figma).
    static let figPeriwinkle1 = Color(hex: 0xB6BEFF) // level 1 (lowest activity)
    static let figPeriwinkle2 = Color(hex: 0x9DA9FF) // level 2
    static let figPeriwinkle3 = Color(hex: 0x8393FF) // level 3
    static let figPeriwinkle4 = Color(hex: 0x6A7EFF) // level 4 (highest activity) / WPM arc / top usage bar

    // Legacy aliases kept for call sites that reference the two-tone naming.
    static let figPeriwinkleStrong = figPeriwinkle4 // WPM arc / top usage bar / strong heatmap
    static let figPeriwinkleMed    = figPeriwinkle4 // gauge arc (alias of strong)
    static let figPeriwinkleLight  = figPeriwinkle1 // lower usage bars / lower-intensity heatmap
    static let figPeriwinkleFaint  = figPeriwinkle1 // heatmap low (alias of light)
    static let figLilac            = Color(hex: 0xEBD6FF) // accent cells
    static let figHeatEmpty        = Color(hex: 0xC9C7BF) // empty heatmap cell
    static let figHeatFuture       = Color(hex: 0xF0F0EB) // future / no-data cell
    static let figChipYellow       = Color(hex: 0xFFEB9C) // "% this month" chip

    /// Heatmap intensity scale, dark (most active) to light, plus the empty grey.
    /// Index 0 = highest activity (figPeriwinkle4) ... index 3 = lowest (figPeriwinkle1),
    /// index 4 = no-activity grey. Used for the legend ("More" -> "Less").
    static let heatmapLegend: [Color] = [
        figPeriwinkle4,
        figPeriwinkle3,
        figPeriwinkle2,
        figPeriwinkle1,
        figHeatEmpty,
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.appInsightCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.figBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, y: 3)
    }
}

extension View {
    func insightCardStyle(padding: CGFloat = 24) -> some View {
        modifier(InsightCard(padding: padding))
    }
}
