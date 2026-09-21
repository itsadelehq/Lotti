import SwiftUI
import AppKit

struct PillView: View {
    @ObservedObject var model: PillModel
    var onCancel: () -> Void, onConfirm: () -> Void

    // Neutral dark grey for the cancel button (matches the Wispr reference) —
    // NOT green, which read as a confirm/positive action.
    private let cancelGrey = Color(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255)

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(cancelGrey))
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

/// Vertical equaliser: a stack of short HORIZONTAL bars whose widths/opacity
/// visibly pulse with the live mic level, like Wispr's waveform. Each bar
/// carries its own phase so they don't all move in lockstep — driven by a
/// continuously-ticking `TimelineView` so the animation is lively even when
/// `level` updates are relatively infrequent.
struct WaveformView: View {
    var level: Float
    private let rows = 5
    private let maxWidth: CGFloat = 22
    // Per-bar phase offsets (radians) and rate multipliers so bars pulse at
    // different speeds rather than moving in unison.
    private let phases: [Double] = [0.0, 1.1, 2.3, 3.6, 4.8]
    private let rates: [Double] = [2.4, 3.1, 2.7, 3.4, 2.9]

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { i in
                    Capsule()
                        .fill(.white)
                        .opacity(opacity(for: i, t: t))
                        .frame(width: width(for: i, t: t), height: 3)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // Center rows react most; a small base width keeps bars visible at rest.
    // A per-bar sine wobble (scaled by the live level) makes the stack read
    // as an animating equaliser rather than a static column.
    private func width(for i: Int, t: TimeInterval) -> CGFloat {
        let distanceFromCenter = abs(Double(i) - Double(rows - 1) / 2)
        let weight = 1.0 - distanceFromCenter / Double(rows) // 0.6...1.0
        let base = 5.0
        let clampedLevel = Double(min(1, max(0, level)))
        let wobble = (sin(t * rates[i] + phases[i]) + 1) / 2 // 0...1
        let dynamic = clampedLevel * (Double(maxWidth) - base) * weight * (0.5 + 0.5 * wobble)
        return CGFloat(base + dynamic)
    }

    private func opacity(for i: Int, t: TimeInterval) -> Double {
        let clampedLevel = Double(min(1, max(0, level)))
        let wobble = (sin(t * rates[i] * 1.3 + phases[i]) + 1) / 2
        return 0.55 + 0.45 * clampedLevel * wobble + (clampedLevel < 0.02 ? 0 : 0)
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
