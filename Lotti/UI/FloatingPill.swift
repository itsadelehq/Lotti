import SwiftUI
import AppKit

struct PillView: View {
    @ObservedObject var model: PillModel
    var onCancel: () -> Void, onConfirm: () -> Void

    // Muted teal-green tint for the cancel button.
    private let cancelGreen = Color(red: 0x2E/255, green: 0x9E/255, blue: 0x73/255)

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(cancelGreen.opacity(0.85)))
            }
            .buttonStyle(.plain)

            WaveformView(level: model.level)
                .frame(width: 24, height: 54)

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .frame(width: 40)
        .background(RoundedRectangle(cornerRadius: 20).fill(.black))
    }
}

final class PillModel: ObservableObject { @Published var level: Float = 0 }

/// Vertical equaliser: a stack of short HORIZONTAL bars whose widths pulse
/// with the audio level, centered in the pill.
struct WaveformView: View {
    var level: Float
    private let rows = 5
    private let maxWidth: CGFloat = 22

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: width(for: i), height: 3)
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.easeOut(duration: 0.08), value: level)
    }

    // Center rows react most; a small base width keeps bars visible at rest.
    private func width(for i: Int) -> CGFloat {
        let distanceFromCenter = abs(Double(i) - Double(rows - 1) / 2)
        let weight = 1.0 - distanceFromCenter / Double(rows) // 0.6...1.0
        let base = 5.0
        let dynamic = Double(min(1, level)) * (Double(maxWidth) - base) * weight
        return CGFloat(base + dynamic)
    }
}

@MainActor final class FloatingPillController {
    private var panel: NSPanel?
    private let model = PillModel()
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    // Slim pill footprint.
    private let pillWidth: CGFloat = 40
    private let pillHeight: CGFloat = 108

    func show() {
        let host = NSHostingController(rootView: PillView(model: model,
            onCancel: { [weak self] in self?.onCancel?() },
            onConfirm: { [weak self] in self?.onConfirm?() }))
        let p = NSPanel(contentRect: .init(x: 0, y: 0, width: pillWidth, height: pillHeight),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true; p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary]
        p.backgroundColor = .clear; p.isOpaque = false; p.hasShadow = true
        p.contentViewController = host
        if let screen = NSScreen.main {
            p.setFrameOrigin(.init(x: screen.frame.midX - pillWidth / 2, y: 120))
        }
        p.orderFrontRegardless()
        panel = p
    }
    func update(level: Float) { model.level = level }
    func hide() { panel?.orderOut(nil); panel = nil }
}
