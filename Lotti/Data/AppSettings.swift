import SwiftUI
import CoreGraphics

final class AppSettings: ObservableObject {
    @AppStorage("triggerKeyCode") var triggerKeyCode: Int = 0x36
    @AppStorage("engine") var engine: String = "deepgram"
    // On by default: runs the Haiku cleanup on every dictation (Wispr-style) so
    // output is corrected and readable. Turn OFF to paste the raw Deepgram
    // smart-formatted transcript immediately (~350ms, no round trip).
    @AppStorage("polishEnabled") var polishEnabled: Bool = true
    // Off by default. When on, pressing the trigger key + spacebar locks the
    // session hands-free (keep recording without holding the key); press the key
    // again to stop. Kept opt-in so a stray spacebar can't accidentally lock and
    // swallow the key release, which used to split/lose dictation.
    @AppStorage("handsFreeLock") var handsFreeLock: Bool = false

    // System
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showFloatingPill") var showFloatingPill: Bool = true
    @AppStorage("showInDock") var showInDock: Bool = true
    @AppStorage("soundsEnabled") var soundsEnabled: Bool = true
    @AppStorage("muteMusicWhileDictating") var muteMusicWhileDictating: Bool = false

    // Appearance. When off, the animated gradient hero banners are hidden
    // app-wide (some people prefer a plain, distraction-free UI).
    @AppStorage("showGradients") var showGradients: Bool = true

    // General
    @AppStorage("appLanguage") var appLanguage: String = "English"
    // Persistent UID of the chosen input device; empty = system default.
    @AppStorage("inputDeviceUID") var inputDeviceUID: String = ""

    // Account
    @AppStorage("firstName") var firstName: String = ""
    @AppStorage("lastName") var lastName: String = ""
    @AppStorage("accountEmail") var accountEmail: String = "adele.sagayam@gmail.com"
}

/// Human-readable labels for a subset of virtual key codes used by the
/// trigger-key recorder in Settings.
enum KeyCodeNaming {
    static let names: [CGKeyCode: String] = [
        0x36: "Right ⌘", 0x37: "Left ⌘",
        0x3D: "Right ⌥", 0x3A: "Left ⌥",
        0x3C: "Right ⇧", 0x38: "Left ⇧",
        0x3E: "Right ⌃", 0x3B: "Left ⌃",
        0x31: "Space", 0x35: "Esc",
        0x3F: "Fn",
    ]
    static func name(for code: Int) -> String {
        names[CGKeyCode(code)] ?? "Key \(code)"
    }
}
