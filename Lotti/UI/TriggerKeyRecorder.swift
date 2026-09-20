import SwiftUI
import AppKit

/// Captures the next key (including modifier-only keys like right-⌘) pressed
/// while recording, and reports its raw `CGKeyCode` back via `onCapture`.
struct TriggerKeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (Int) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let v = RecorderView()
        v.onCapture = onCapture
        return v
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.onCapture = onCapture
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class RecorderView: NSView {
        var onCapture: ((Int) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func flagsChanged(with event: NSEvent) {
            onCapture?(Int(event.keyCode))
        }
        override func keyDown(with event: NSEvent) {
            onCapture?(Int(event.keyCode))
        }
    }
}
