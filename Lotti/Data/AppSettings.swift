import SwiftUI
import CoreGraphics

final class AppSettings: ObservableObject {
    @AppStorage("triggerKeyCode") var triggerKeyCode: Int = 0x36
    @AppStorage("engine") var engine: String = "deepgram"
    @AppStorage("polishEnabled") var polishEnabled: Bool = true
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
    ]
    static func name(for code: Int) -> String {
        names[CGKeyCode(code)] ?? "Key \(code)"
    }
}
