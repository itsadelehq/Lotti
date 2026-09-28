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
    /// Latest INTERIM (non-final) transcript. Used as a fallback so a tail that
    /// was still interim when recording stopped isn't lost.
    private var lastInterim: String = ""
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
        finals.removeAll(); lastInterim = ""; startedAt = Date()
        targetApp = inject ? TextInjector.frontmostAppBundleId() : nil
        Sounds.playStart()
        pill?.show()
        AppLog.log("Coordinator.begin: recording started (target app: \(targetApp ?? "n/a"))")

        let hasKey = deepgramKeyPresent()
        if !hasKey {
            // Still show the pill (already shown) so the user gets feedback, but
            // don't start the engine — there's nothing to transcribe with.
            AppLog.log("No Deepgram key — open Settings → Keys. Skipping transcription engine.")
            Toaster.shared.error("Add your Deepgram key in Settings → Keys")
        }

        if hasKey {
            let e = makeEngine(); engine = e
            e.onTranscript = { [weak self] text, isFinal in
                Task { @MainActor in
                    if isFinal { self?.finals.append(text) }
                    else { self?.lastInterim = text }
                }
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

    /// Called when hands-free lock engages (trigger key + spacebar). Reflects it
    /// on the floating pill so the user knows releasing the key won't stop it.
    func lockEngaged() {
        pill?.setLocked(true)
        AppLog.log("[Lotti] Coordinator: hands-free lock engaged")
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

        // Flush Deepgram and WAIT for the trailing final transcript(s) that arrive
        // a few hundred ms after Finalize — finish() only returns once they've been
        // delivered via onTranscript (and the socket has been closed). This is what
        // keeps the END of longer/faster speech ("tail") from being dropped.
        if let e {
            await e.finish()
            // Let any final onTranscript MainActor hops that were enqueued just
            // before finish() resumed drain into `finals`/`lastInterim`.
            await drainPendingTranscripts()
        }
        let lastFinalAt = Date()
        AppLog.log(String(format: "[Lotti] timing keyUp→finishReturned: %.0fms",
                          lastFinalAt.timeIntervalSince(keyUp) * 1000))

        var raw = finals.joined(separator: " ")
        // Fallback: if the very last thing spoken was still an interim (finals
        // never caught up to it), append it so no trailing words are lost.
        let interim = lastInterim.trimmingCharacters(in: .whitespacesAndNewlines)
        if !interim.isEmpty,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .hasSuffix(interim) {
            raw = raw.isEmpty ? interim : raw + " " + interim
            AppLog.log("[Lotti] tail fallback: appended trailing interim")
        }
        AppLog.log(String(format: "[Lotti] timing keyUp→lastFinal: %.0fms",
                          lastFinalAt.timeIntervalSince(keyUp) * 1000))
        guard !raw.isEmpty else {
            AppLog.log("Coordinator.end: empty transcript — nothing saved")
            return
        }

        // Cleanup is ON by default: a missing key means the user never opted out,
        // so treat nil as true (matches the registered default and AppSettings).
        let polishEnabled = UserDefaults.standard.object(forKey: "polishEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "polishEnabled")
        let polisher = polishEnabled ? makePolish() : nil

        // Polish once with Haiku (when enabled), then paste a single time. An
        // earlier build tried an "instant paste raw, then swap in the cleaned
        // version" trick for a Wispr-like feel, but swapping in place needs
        // rapid synthetic backspaces, and Electron/web apps (Claude desktop,
        // Slack, etc.) silently DROP some of them — leaving corrupted/duplicated
        // text. A single correct paste is worth the ~1s. nova-3's smart-format
        // already makes the raw clean, so even the fallback (polish failed) is
        // presentable. Snippets are expanded LAST so expansions are verbatim.
        let snippets = store.snippets()
        var finalText = raw
        if let polisher {
            finalText = (try? await polisher.polish(raw)) ?? raw
        }
        let polishAt = Date()
        AppLog.log(String(format: "[Lotti] timing lastFinal→haiku: %.0fms",
                          polishAt.timeIntervalSince(lastFinalAt) * 1000))
        finalText = Self.expandSnippets(in: finalText, snippets: snippets)

        if inject { TextInjector.paste(finalText) }
        AppLog.log("[Lotti] pasted text: \"\(String(finalText.prefix(160)))\"")
        AppLog.log(String(format: "[Lotti] timing total keyUp→pasted: %.0fms",
                          Date().timeIntervalSince(keyUp) * 1000))

        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        store.add(Dictation(rawText: raw, polishedText: finalText,
            appBundleId: targetApp, durationSeconds: duration))
        let words = finalText.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        AppLog.log("Coordinator.end: saved dictation (\(words) words)")
    }

    /// Replaces any spoken snippet NAME occurrences in `text` with the
    /// snippet's EXPANSION. Case-insensitive, whole-phrase (word-boundary
    /// aware) matching so "my LinkedIn" matches "send my LinkedIn please"
    /// but not a substring of another word. Longer names are applied first
    /// to avoid partial overlaps, and trailing punctuation on the spoken name
    /// is tolerated (Deepgram may append a period).
    static func expandSnippets(in text: String, snippets: [Snippet]) -> String {
        var result = text
        // Longest names first so "my LinkedIn page" wins over "my LinkedIn".
        let sorted = snippets
            .map { (name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), expansion: $0.expansion) }
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }

        for snippet in sorted {
            // Strip trailing punctuation the speaker's name shouldn't include,
            // then escape for a literal regex match. Allow optional trailing
            // punctuation (e.g. a Deepgram period) after the matched phrase.
            let cleanName = snippet.name.trimmingCharacters(in: CharacterSet(charactersIn: " .,!?;:"))
            guard !cleanName.isEmpty else { continue }
            let escaped = NSRegularExpression.escapedPattern(for: cleanName)
            // (?<![\w]) / (?![\w]) are word boundaries that also work when the
            // phrase contains spaces (unlike \b at both ends).
            let pattern = "(?<![\\p{L}\\p{N}])\(escaped)[.,!?;:]*(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matchCount = regex.numberOfMatches(in: result, options: [], range: range)
            guard matchCount > 0 else { continue }
            let template = NSRegularExpression.escapedTemplate(for: snippet.expansion)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: template)
            AppLog.log("[Lotti] snippet expanded: \"\(cleanName)\"")
        }
        return result
    }

    /// The engine delivers trailing finals via `onTranscript`, which hops to the
    /// MainActor asynchronously. When `finish()` resumes, the last such hop may
    /// still be queued; wait briefly until `finals` stops growing so the tail is
    /// fully accumulated before we build the transcript. Bounded and short.
    private func drainPendingTranscripts() async {
        var lastCount = -1
        for _ in 0..<8 { // up to ~160ms
            let count = finals.count
            if count == lastCount { return } // settled
            lastCount = count
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }
}
