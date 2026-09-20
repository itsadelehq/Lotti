import Foundation

@MainActor final class DictationCoordinator {
    private let store: Store
    private let makeEngine: () -> TranscriptionEngine
    private let polish: PolishService?
    private let inject: Bool
    private var engine: TranscriptionEngine?
    private var audio: AudioCapture?
    private var pill: FloatingPillController?
    private var finals: [String] = []
    private var startedAt: Date?
    private var targetApp: String?

    init(store: Store, makeEngine: @escaping () -> TranscriptionEngine,
         polish: PolishService?, inject: Bool = true,
         pill: FloatingPillController? = nil, audio: AudioCapture? = nil) {
        self.store = store; self.makeEngine = makeEngine
        self.polish = polish; self.inject = inject
        self.pill = pill; self.audio = audio
    }

    func begin() {
        finals.removeAll(); startedAt = Date()
        targetApp = inject ? TextInjector.frontmostAppBundleId() : nil
        Sounds.playStart()
        pill?.show()
        let e = makeEngine(); engine = e
        e.onTranscript = { [weak self] text, isFinal in
            Task { @MainActor in if isFinal { self?.finals.append(text) } }
        }
        Task { try? await e.start() }
        if inject {
            let cap = AudioCapture(); audio = cap
            cap.onPCM = { [weak self] d in
                Task { @MainActor in self?.engine?.send(d) }
            }
            cap.onLevel = { [weak self] l in
                Task { @MainActor in self?.pill?.update(level: l) }
            }
            try? cap.start()
        }
    }

    func end(cancelled: Bool) async {
        audio?.stop()
        await engine?.finish()
        Sounds.playEnd()
        pill?.hide()
        defer { engine = nil; audio = nil }
        if cancelled { return }
        let raw = finals.joined(separator: " ")
        guard !raw.isEmpty else { return }
        let polished = (try? await polish?.polish(raw)) ?? raw
        if inject { TextInjector.paste(polished) }
        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        store.add(Dictation(rawText: raw, polishedText: polished,
            appBundleId: targetApp, durationSeconds: duration))
    }
}
