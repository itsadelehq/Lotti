import SwiftUI
import AppKit

struct PillView: View {
    @ObservedObject var model: PillModel
    var onCancel: () -> Void, onConfirm: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Button(action: onCancel) { Image(systemName: "xmark") }
                .buttonStyle(.plain).padding(6)
                .background(Circle().fill(.gray.opacity(0.4)))
            WaveformView(level: model.level)   // simple bar-height view driven by level
                .frame(width: 26, height: 90)
            Button(action: onConfirm) { Image(systemName: "checkmark") }
                .buttonStyle(.plain).padding(8)
                .background(Circle().fill(.white))
                .foregroundStyle(.black)
        }
        .padding(.vertical, 12)
        .frame(width: 58)
        .background(RoundedRectangle(cornerRadius: 29).fill(.black))
    }
}

final class PillModel: ObservableObject { @Published var level: Float = 0 }

struct WaveformView: View {
    var level: Float
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Capsule().fill(.white)
                    .frame(height: CGFloat(10 + level * 60 * Float((i % 2) + 1)))
            }
        }
    }
}

@MainActor final class FloatingPillController {
    private var panel: NSPanel?
    private let model = PillModel()
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    func show() {
        let host = NSHostingController(rootView: PillView(model: model,
            onCancel: { [weak self] in self?.onCancel?() },
            onConfirm: { [weak self] in self?.onConfirm?() }))
        let p = NSPanel(contentRect: .init(x: 0, y: 0, width: 58, height: 150),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true; p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary]
        p.backgroundColor = .clear; p.isOpaque = false; p.hasShadow = true
        p.contentViewController = host
        if let screen = NSScreen.main {
            p.setFrameOrigin(.init(x: screen.frame.midX - 29, y: 120))
        }
        p.orderFrontRegardless()
        panel = p
    }
    func update(level: Float) { model.level = level }
    func hide() { panel?.orderOut(nil); panel = nil }
}
