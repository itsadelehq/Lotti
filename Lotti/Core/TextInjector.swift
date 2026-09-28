// Core/TextInjector.swift
import AppKit

enum TextInjector {
    static func frontmostAppBundleId() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    static func paste(_ text: String) {
        AppLog.log("TextInjector: pasting \(text.count) chars into \(frontmostAppBundleId() ?? "unknown")")
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        pb.clearContents(); pb.setString(text, forType: .string)
        sendCmdV()
        // restore clipboard shortly after paste lands
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pb.clearContents()
            if let saved { pb.setString(saved, forType: .string) }
        }
    }
    /// Replace text that was just pasted with `paste(...)`: delete
    /// `previousCount` characters (backspaces) then paste `text`. Used by the
    /// instant-paste path to swap raw dictation for the Haiku-cleaned version
    /// in place. Only safe when the same field still has focus — the caller
    /// guards on the frontmost app being unchanged.
    static func replacePasted(previousCount: Int, with text: String) {
        AppLog.log("TextInjector: replacing \(previousCount) chars in place with \(text.count)")
        sendBackspaces(previousCount)
        paste(text)
    }
    private static func sendBackspaces(_ n: Int) {
        guard n > 0 else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        let del: CGKeyCode = 0x33 // Backspace/Delete
        for _ in 0..<n {
            CGEvent(keyboardEventSource: src, virtualKey: del, keyDown: true)?
                .post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: src, virtualKey: del, keyDown: false)?
                .post(tap: .cghidEventTap)
        }
    }
    private static func sendCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 0x09
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
