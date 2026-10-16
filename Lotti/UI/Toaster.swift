import SwiftUI

/// App-wide, lightweight error/info feedback. A single shared instance publishes
/// the current `message`; `RootView` renders it as a floating toast. Failures
/// across the app call `Toaster.shared.error(...)` so nothing fails silently.
@MainActor
final class Toaster: ObservableObject {
    static let shared = Toaster()

    /// The text currently shown, or `nil` when no toast is visible.
    @Published var message: String?
    /// Whether the current toast is an error (dark) or info (neutral).
    @Published var isError = true

    private var clearTask: Task<Void, Never>?

    private init() {}

    /// Show an error toast (dark capsule with a warning glyph). Safe to call from
    /// any actor, it hops to the main actor.
    nonisolated func error(_ text: String) {
        Task { @MainActor in self.present(text, isError: true) }
    }

    /// Show an informational toast (neutral capsule).
    nonisolated func info(_ text: String) {
        Task { @MainActor in self.present(text, isError: false) }
    }

    private func present(_ text: String, isError: Bool) {
        self.isError = isError
        self.message = text
        clearTask?.cancel()
        clearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            self.message = nil
        }
    }

    /// Dismiss immediately (e.g. on click).
    func dismiss() {
        clearTask?.cancel()
        message = nil
    }
}

/// Floating toast presented as an overlay by `RootView`. A rounded capsule —
/// dark (#1A1A1A) for errors with a small warning glyph, neutral for info —
/// that fades in/out and disappears on its own or on click. Non-blocking.
struct ToastView: View {
    @ObservedObject var toaster = Toaster.shared

    var body: some View {
        VStack {
            if let message = toaster.message {
                capsule(message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 18)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(toaster.message != nil)
        .animation(.easeInOut(duration: 0.22), value: toaster.message)
    }

    private func capsule(_ message: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: toaster.isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(message)
                .font(.gsMedium(13))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            Capsule().fill(toaster.isError ? Color(hex: 0x1A1A1A) : Color(hex: 0x3A3A3A))
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
        .contentShape(Capsule())
        .onTapGesture { toaster.dismiss() }
    }
}
