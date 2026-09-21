import SwiftUI
import WebKit

/// A transparent, non-interactive `WKWebView` that renders the bundled
/// `quote-shader.html` — a ShaderGradient (WebGL/R3F) animated grainy
/// gradient — as a lightweight background layer.
///
/// The web view never accepts clicks or hover: it sits purely as decoration
/// behind interactive SwiftUI content (e.g. the quote banner's dismiss
/// button), via `NonInteractiveWebView.hitTest` returning `nil`.
struct ShaderGradientView: NSViewRepresentable {
    func makeNSView(context: Context) -> NonInteractiveWebView {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = false

        let webView = NonInteractiveWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }

        if let url = Bundle.main.url(forResource: "quote-shader", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ nsView: NonInteractiveWebView, context: Context) {
        // Static content; nothing to update.
    }
}

/// `WKWebView` subclass that never intercepts mouse events, so it can be
/// layered underneath interactive SwiftUI controls without stealing clicks.
final class NonInteractiveWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
