import SwiftUI
import AppKit

struct PillView: View {
    @ObservedObject var model: PillModel
    var onCancel: () -> Void, onConfirm: () -> Void

    // Neutral dark grey for the cancel button (matches the Wispr reference) —
    // NOT green, which read as a confirm/positive action.
    private let cancelGrey = Color(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255)

    var body: some View {
        VStack(spacing: 4) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(cancelGrey))
            }
            .buttonStyle(.plain)
            // Nudge the ✕ down a few points so it isn't touching the top edge.
            .padding(.top, 4)

            // Waveform tightened by the same amount we inset the two buttons,
            // so the pill's overall height is unchanged.
            WaveformView(level: model.level)
                .frame(width: 24, height: 52)
                // Subtle hands-free indicator: a small lock glyph overlaid on the
                // waveform so the user knows releasing the key won't stop it.
                .overlay(alignment: .center) {
                    if model.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Circle().fill(cancelGrey.opacity(0.9)))
                    }
                }

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.white))
            }
            .buttonStyle(.plain)
            // Nudge the ✓ up a few points so it isn't touching the bottom edge.
            .padding(.bottom, 4)
        }
        .padding(.vertical, 5)
        .frame(width: 40)
        .background(RoundedRectangle(cornerRadius: 20).fill(.black))
        // A subtle teal border while hands-free lock is engaged.
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appTeal, lineWidth: model.isLocked ? 1.5 : 0)
        )
    }
}

final class PillModel: ObservableObject {
    @Published var level: Float = 0
    @Published var isLocked: Bool = false
}

/// Vertical equaliser: a stack of short HORIZONTAL bars whose widths/opacity
/// visibly pulse with the live mic level, like Wispr's waveform. Each bar
/// carries its own phase so they don't all move in lockstep — driven by a
/// continuously-ticking `TimelineView` so the animation is lively even when
/// `level` updates are relatively infrequent.
struct WaveformView: View {
    var level: Float
    private let rows = 13
    private let maxWidth: CGFloat = 24
    // Per-bar phase offsets (radians) and rate multipliers so bars pulse at
    // different speeds rather than moving in unison. Generated to cover
    // `rows` bars with varied phase/rate so no two bars move identically.
    private let phases: [Double] = [0.0, 0.9, 1.8, 2.7, 3.6, 4.5, 5.4, 0.5, 1.4, 2.3, 3.2, 4.1, 5.0]
    private let rates: [Double] = [2.4, 3.1, 2.7, 3.4, 2.9, 2.5, 3.3, 2.8, 3.0, 2.6, 3.5, 2.7, 3.2]

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            VStack(spacing: 1) {
                ForEach(0..<rows, id: \.self) { i in
                    Capsule()
                        .fill(.white)
                        .opacity(opacity(for: i, t: t))
                        .frame(width: width(for: i, t: t), height: 1.6)
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
        let base = 3.0
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
    private let pillHeight: CGFloat = 110

    func show() {
        // Reset any prior locked state whenever a fresh session's pill appears.
        model.isLocked = false
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
    /// Reflects hands-free lock state on the pill (lock glyph + teal border).
    func setLocked(_ isLocked: Bool) { model.isLocked = isLocked }
    func hide() { panel?.orderOut(nil); panel = nil }
}
