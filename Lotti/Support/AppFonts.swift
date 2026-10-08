import SwiftUI
import CoreText
import AppKit

/// Registers the bundled Inter fonts at launch and exposes
/// `Font.gsBold/gsMedium/gsRegular` helpers. Falls back to system rounded
/// fonts if registration or the family lookup fails for any reason.
///
/// Inter (SIL Open Font License) is the open-source default. The private
/// Aeonik Pro build simply drops `AeonikPro-*.ttf` back into Resources/Fonts
/// and swaps these four names — everything else is unchanged.
///
/// Registration happens two ways for reliability:
///  (a) `ATSApplicationFontsPath` = `Fonts` in Info.plist (bundle auto-registers), and
///  (b) programmatic `CTFontManagerRegisterFontsForURL` here as a backup.
enum AppFonts {
    /// Family name of the bundled sans.
    static let familyName = "Inter"
    /// Exact PostScript names of the bundled Inter static faces.
    static let psRegular  = "Inter-Regular"
    static let psMedium   = "Inter-Medium"
    static let psSemibold = "Inter-SemiBold"
    static let psBold     = "Inter-Bold"

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
        // Register every bundled ttf (Inter, Lora, Instrument Serif).
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
        setbuf(stdout, nil) // flush the verification prints immediately
        _ = registered
        // Runtime verification requested in the task – confirms the faces
        // resolve by their explicit PostScript names.
        let bold = NSFont(name: psBold, size: 12) != nil
        let semibold = NSFont(name: psSemibold, size: 12) != nil
        let medium = NSFont(name: psMedium, size: 12) != nil
        let regular = NSFont(name: psRegular, size: 12) != nil
        print("[AppFonts] family=\(familyName) registered=\(registered) bold=\(bold) semibold=\(semibold) medium=\(medium) regular=\(regular)")
        // Lora (serif) verification – confirms the bundled variable font's named
        // instances resolve by their CoreText PostScript names.
        let loraReg = NSFont(name: loraPSRegular, size: 12) != nil
        let loraMed = NSFont(name: loraPSMedium, size: 12) != nil
        let loraSemi = NSFont(name: loraPSSemibold, size: 12) != nil
        let loraBld = NSFont(name: loraPSBold, size: 12) != nil
        print("[AppFonts] Lora regular(Lora-Regular)=\(loraReg) medium=\(loraMed) semibold=\(loraSemi) bold=\(loraBld)")
    }

    // MARK: - Lora (serif)
    /// Family + CoreText-verified PostScript names for the bundled Lora variable
    /// font. The named instances resolve as `Lora-Regular`, `Lora-Regular_Medium`,
    /// etc. (verified via `NSFontManager.availableMembers`).
    static let loraFamily      = "Lora"
    static let loraPSRegular   = "Lora-Regular"
    static let loraPSMedium    = "Lora-Regular_Medium"
    static let loraPSSemibold  = "Lora-Regular_SemiBold"
    static let loraPSBold      = "Lora-Regular_Bold"

    static func lora(size: CGFloat, weight: Font.Weight) -> Font {
        let ps: String
        switch weight {
        case .bold, .heavy, .black: ps = loraPSBold
        case .semibold: ps = loraPSSemibold
        case .medium: ps = loraPSMedium
        default: ps = loraPSRegular
        }
        // Only use the custom face if it actually resolved; otherwise fall back
        // to the system serif so text never disappears.
        guard NSFont(name: ps, size: size) != nil else {
            return .system(size: size, weight: weight, design: .serif)
        }
        return .custom(ps, size: size)
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
    static func gsSemibold(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .semibold) }
    static func gsMedium(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .medium) }
    static func gsRegular(_ size: CGFloat) -> Font { AppFonts.font(size: size, weight: .regular) }

    static func loraRegular(_ size: CGFloat) -> Font { AppFonts.lora(size: size, weight: .regular) }
    static func loraMedium(_ size: CGFloat) -> Font { AppFonts.lora(size: size, weight: .medium) }
    static func loraSemiBold(_ size: CGFloat) -> Font { AppFonts.lora(size: size, weight: .semibold) }
    static func loraBold(_ size: CGFloat) -> Font { AppFonts.lora(size: size, weight: .bold) }

    /// Instrument Serif (elegant display serif) — used for the daily quote.
    static func instrumentSerif(_ size: CGFloat) -> Font {
        NSFont(name: "InstrumentSerif-Regular", size: size) != nil
            ? .custom("InstrumentSerif-Regular", size: size)
            : .system(size: size, design: .serif)
    }
    static func instrumentSerifItalic(_ size: CGFloat) -> Font {
        NSFont(name: "InstrumentSerif-Italic", size: size) != nil
            ? .custom("InstrumentSerif-Italic", size: size)
            : .system(size: size, design: .serif).italic()
    }
}

/// Shared heading sizes so screen titles and section headings stay
/// consistent app-wide. Metric/stat numbers are NOT part of this scale.
enum AppFontSizes {
    /// Top-level screen titles ("Insights", "Welcome back, Adele", "Settings").
    static let screenTitle: CGFloat = 32
    /// Section headings inside a screen ("Desktop usage", "{n} day streak").
    static let sectionHeading: CGFloat = 23
}
