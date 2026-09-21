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
    var preset: ShaderPreset

    func makeNSView(context: Context) -> NonInteractiveWebView {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = false

        let webView = NonInteractiveWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }

        load(preset, into: webView)

        return webView
    }

    func updateNSView(_ nsView: NonInteractiveWebView, context: Context) {
        // Reload whenever the day's preset changes (e.g. the same view
        // instance is reused across a midnight rollover).
        if nsView.loadedPresetKey != preset.key {
            load(preset, into: nsView)
        }
    }

    /// Builds `quote-shader.html?c1=...&c2=...&c3=...&type=...` on the
    /// bundled file URL and loads it. `loadFileURL` accepts query items on
    /// the URL just fine — the page reads them back via
    /// `window.location.search`.
    private func load(_ preset: ShaderPreset, into webView: NonInteractiveWebView) {
        guard let baseURL = Bundle.main.url(forResource: "quote-shader", withExtension: "html") else {
            return
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "c1", value: preset.c1),
            URLQueryItem(name: "c2", value: preset.c2),
            URLQueryItem(name: "c3", value: preset.c3),
            URLQueryItem(name: "type", value: preset.type)
        ]

        let url = components?.url ?? baseURL
        webView.loadedPresetKey = preset.key
        webView.loadFileURL(url, allowingReadAccessTo: baseURL.deletingLastPathComponent())
    }
}

/// `WKWebView` subclass that never intercepts mouse events, so it can be
/// layered underneath interactive SwiftUI controls without stealing clicks.
final class NonInteractiveWebView: WKWebView {
    /// Tracks which preset is currently loaded so `updateNSView` only
    /// reloads the page when the preset actually changes.
    var loadedPresetKey: String?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
