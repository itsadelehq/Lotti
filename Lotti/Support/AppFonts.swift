import SwiftUI
import CoreText
import AppKit

/// Registers the bundled Aeonik Pro fonts at launch and exposes
/// `Font.gsBold/gsMedium/gsRegular` helpers. Falls back to system rounded
/// fonts if registration or the family lookup fails for any reason.
///
/// Registration happens two ways for reliability:
///  (a) `ATSApplicationFontsPath` = `Fonts` in Info.plist (bundle auto-registers), and
///  (b) programmatic `CTFontManagerRegisterFontsForURL` here as a backup.
enum AppFonts {
    /// Family name verified from the bundled ttf `name` table via CoreText.
    static let familyName = "Aeonik Pro"
    /// Exact PostScript names verified via CoreText (see task notes).
    static let psRegular  = "AeonikPro-Regular"
    static let psMedium   = "AeonikPro-Medium"
    static let psSemibold = "AeonikPro-SemiBold"
    static let psBold     = "AeonikPro-Bold"

    private static let registered: Bool = {
        // Look in the "Fonts" subdirectory first (matches ATSApplicationFontsPath),
        // then fall back to a flat Resources search.
        var fontURLs: [URL] = []
        if let inFonts = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") {
            fontURLs += inFonts
        }
        if let flat = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
            fontURLs += flat
        }
        // Register every bundled ttf (Aeonik Pro and any remaining Google Sans files).
        for url in fontURLs {
            var error: Unmanaged<CFError>?
            // Ignore "already registered" errors – ATSApplicationFontsPath may have
            // registered these already; the family lookup below is the real check.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
        // The PostScript bold face resolving is the definitive proof the font is live.
        return NSFont(name: psBold, size: 12) != nil
            || NSFontManager.shared.availableFontFamilies.contains(familyName)
    }()

    static func register() {
        _ = registered
        // Runtime verification requested in the task – confirms the faces
        // resolve by their explicit PostScript names.
        let bold = NSFont(name: psBold, size: 12) != nil
        let semibold = NSFont(name: psSemibold, size: 12) != nil
        let medium = NSFont(name: psMedium, size: 12) != nil
        let regular = NSFont(name: psRegular, size: 12) != nil
        print("[AppFonts] registered=\(registered) bold(AeonikPro-Bold)=\(bold) semibold=\(semibold) medium=\(medium) regular=\(regular)")
    }

    static func font(size: CGFloat, weight: Font.Weight) -> Font {
        guard registered else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        // Prefer explicit PostScript names – addresses the named instances directly.
        let ps: String
        switch weight {
        case .bold, .heavy, .black: ps = psBold
        case .semibold: ps = psSemibold
        case .medium: ps = psMedium
        default: ps = psRegular
        }
        return .custom(ps, size: size)
    }
}

extension Font {
    static func gsBold(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .bold) }
    static func gsMedium(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .medium) }
    static func gsRegular(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .regular) }
}

/// Shared heading sizes so screen titles and section headings stay
/// consistent app-wide. Metric/stat numbers are NOT part of this scale.
enum AppFontSizes {
    /// Top-level screen titles ("Insights", "Welcome back, Adele", "Settings").
    static let screenTitle: CGFloat = 32
    /// Section headings inside a screen ("Desktop usage", "{n} day streak").
    static let sectionHeading: CGFloat = 23
}
