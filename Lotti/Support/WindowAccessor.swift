import SwiftUI
import AppKit

/// Forces the hosting `NSWindow`'s background color to match the app's base
/// canvas color (`Color.appBg` / `#F5F4F1`) so no default white/system
/// material shows through at the window edges, behind the sidebar vibrancy,
/// or during resize — keeping the base background identical everywhere.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.backgroundColor = Color.appBgNS
                window.isOpaque = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.backgroundColor = Color.appBgNS
        }
    }
}
