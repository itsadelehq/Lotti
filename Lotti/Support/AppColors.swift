import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static let appBg = Color(hex: 0xF5F4F1)
    static let appSidebarBg = Color(hex: 0xF5F4F1)
    static let appCard = Color.white
    static let appCardMuted = Color(hex: 0xF0EFEB)
    static let appTextPrimary = Color(hex: 0x1A1A1A)
    static let appTextSecondary = Color(hex: 0x8A8A82)
    static let appTeal = Color(hex: 0x0E5A4F)
    static let appTealDeep = Color(hex: 0x0B463D)
    static let appGreenChipBg = Color(hex: 0xD8F0DF)
    static let appGreenChipText = Color(hex: 0x1B7A4B)
    static let appOrange = Color(hex: 0xF6A93B)
    static let appPillBlack = Color(hex: 0x1B1B1D)
    static let appProBg = Color(hex: 0xEDE7FB)
    static let appProText = Color(hex: 0x6C4BD8)
    static let appHairline = Color.black.opacity(0.06)
    static let appDivider = Color.black.opacity(0.08)

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
