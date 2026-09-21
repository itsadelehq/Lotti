import SwiftUI
import CoreGraphics

final class AppSettings: ObservableObject {
    @AppStorage("triggerKeyCode") var triggerKeyCode: Int = 0x36
    @AppStorage("engine") var engine: String = "deepgram"
    // Off by default: pastes the Deepgram smart-formatted transcript immediately
    // (~350ms) instead of waiting on the Haiku polish call (~1.4s). Opt in for
    // higher-accuracy cleanup at the cost of latency.
    @AppStorage("polishEnabled") var polishEnabled: Bool = false

    // System
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showFloatingPill") var showFloatingPill: Bool = true
    @AppStorage("showInDock") var showInDock: Bool = true
    @AppStorage("soundsEnabled") var soundsEnabled: Bool = true
    @AppStorage("muteMusicWhileDictating") var muteMusicWhileDictating: Bool = false

    // General
    @AppStorage("appLanguage") var appLanguage: String = "English"

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
