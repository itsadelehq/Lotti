import SwiftUI
import CoreText
import AppKit

/// Registers the bundled Google Sans variable fonts at launch and exposes
/// `Font.gsBold/gsMedium/gsRegular` helpers. Falls back to system rounded
/// fonts if registration or the family lookup fails for any reason.
enum AppFonts {
    /// PostScript family name verified from the bundled ttf's `name` table.
    static let familyName = "Google Sans"

    private static let registered: Bool = {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else {
            return false
        }
        let fontURLs = urls.filter { $0.lastPathComponent.contains("GoogleSans") }
        guard !fontURLs.isEmpty else { return false }
        for url in fontURLs {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
        return NSFontManager.shared.availableFontFamilies.contains(familyName)
    }()

    static func register() { _ = registered }

    static func font(size: CGFloat, weight: Font.Weight) -> Font {
        if registered {
            return .custom(familyName, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

extension Font {
    static func gsBold(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .bold) }
    static func gsMedium(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .medium) }
    static func gsRegular(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .regular) }
}
