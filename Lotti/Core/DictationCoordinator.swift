import Foundation

@MainActor final class DictationCoordinator {
    private let store: Store
    private let makeEngine: () -> TranscriptionEngine
    /// Reads the Anthropic key at dictation time (in `end()`), so a key entered
    /// in Settings takes effect on the NEXT dictation without a relaunch. Mirrors
    /// how `makeEngine` reads the Deepgram key lazily at `begin()`.
    private let makePolish: () -> PolishService?
    /// Reports whether a Deepgram key is present at `begin()` time, so we can log
    /// a clear message and skip the engine gracefully when it is missing.
    private let deepgramKeyPresent: () -> Bool
    private let inject: Bool
    private var engine: TranscriptionEngine?
    private var audio: AudioCapture?
    private var pill: FloatingPillController?
    private var finals: [String] = []
    private var startedAt: Date?
    private var targetApp: String?

    init(store: Store, makeEngine: @escaping () -> TranscriptionEngine,
         makePolish: @escaping () -> PolishService? = { nil },
         deepgramKeyPresent: @escaping () -> Bool = { true },
         inject: Bool = true,
         pill: FloatingPillController? = nil, audio: AudioCapture? = nil) {
        self.store = store; self.makeEngine = makeEngine
        self.makePolish = makePolish
        self.deepgramKeyPresent = deepgramKeyPresent
        self.inject = inject
        self.pill = pill; self.audio = audio
    }

    func begin() {
        finals.removeAll(); startedAt = Date()
        targetApp = inject ? TextInjector.frontmostAppBundleId() : nil
        Sounds.playStart()
        pill?.show()
        AppLog.log("Coordinator.begin: recording started (target app: \(targetApp ?? "n/a"))")

        let hasKey = deepgramKeyPresent()
        if !hasKey {
            // Still show the pill (already shown) so the user gets feedback, but
            // don't start the engine — there's nothing to transcribe with.
            AppLog.log("No Deepgram key — open Settings → Keys. Skipping transcription engine.")
        }

        if hasKey {
            let e = makeEngine(); engine = e
            e.onTranscript = { [weak self] text, isFinal in
                Task { @MainActor in if isFinal { self?.finals.append(text) } }
            }
            Task {
                do { try await e.start() }
                catch { AppLog.log("Coordinator.begin: engine.start() error — \(error.localizedDescription)") }
            }
        }

        if inject {
            let cap = AudioCapture(); audio = cap
            cap.onPCM = { [weak self] d in
                Task { @MainActor in self?.engine?.send(d) }
            }
            cap.onLevel = { [weak self] l in
                Task { @MainActor in self?.pill?.update(level: l) }
            }
            do { try cap.start() }
            catch { AppLog.log("Coordinator.begin: AudioCapture.start() error — \(error.localizedDescription)") }
        }
    }

    func end(cancelled: Bool) async {
        let keyUp = Date()
        audio?.stop()
        let e = engine
        defer { engine = nil; audio = nil }

        Sounds.playEnd()
        pill?.hide()

        if cancelled {
            e?.close() // background teardown, not awaited
            AppLog.log("Coordinator.end: cancelled — nothing saved")
            return
        }

        // Flush Deepgram so it emits any last final transcript, then wait only
        // a short bounded window for it — do NOT block on the WS close handshake.
        e?.finalize()
        await waitForFinalizedTranscript(maxWait: 0.30)
        let lastFinalAt = Date()
        // Close the socket in the background; the paste path never awaits it.
        e?.close()

        let raw = finals.joined(separator: " ")
        AppLog.log(String(format: "[Lotti] timing keyUp→lastFinal: %.0fms",
                          lastFinalAt.timeIntervalSince(keyUp) * 1000))
        guard !raw.isEmpty else {
            AppLog.log("Coordinator.end: empty transcript — nothing saved")
            return
        }

        // Polish with Haiku only when the user opted in via Settings; otherwise
        // paste the smart-formatted Deepgram text directly (near-instant path,
        // ~350ms instead of ~1.4s for the Haiku round trip).
        let polishEnabled = UserDefaults.standard.bool(forKey: "polishEnabled")
        let polished: String
        if polishEnabled, let polisher = makePolish() {
            polished = (try? await polisher.polish(raw)) ?? raw
        } else {
            polished = raw
        }
        let polishAt = Date()
        AppLog.log(String(format: "[Lotti] timing lastFinal→haiku: %.0fms",
                          polishAt.timeIntervalSince(lastFinalAt) * 1000))

        if inject { TextInjector.paste(polished) }
        let pasteAt = Date()
        AppLog.log(String(format: "[Lotti] timing haiku→pasted: %.0fms | total keyUp→pasted: %.0fms",
                          pasteAt.timeIntervalSince(polishAt) * 1000,
                          pasteAt.timeIntervalSince(keyUp) * 1000))

        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        store.add(Dictation(rawText: raw, polishedText: polished,
            appBundleId: targetApp, durationSeconds: duration))
        let words = polished.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        AppLog.log("Coordinator.end: saved dictation (\(words) words)")
    }

    /// Poll briefly for a late final transcript to land after `finalize()`.
    /// Returns as soon as `finals` grows, or after `maxWait` seconds.
    private func waitForFinalizedTranscript(maxWait: TimeInterval) async {
        let deadline = Date().addingTimeInterval(maxWait)
        let before = finals.count
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            if finals.count > before { return }
        }
    }
}
