import SwiftUI
import AppKit

/// Full-screen note editor (Figma screen 2). A large serif title field, a meta
/// chip row, a multi-line body editor that autosaves on change, and a bottom
/// floating bar with a live mic-record control (reuses `AudioCapture` +
/// `DeepgramEngine`) plus a cosmetic "Ask anything" pill.
struct NoteEditorView: View {
    @EnvironmentObject var store: Store
    let note: Note
    /// Label for the back control (e.g. "Notetaker" or "Scratchpad") so the
    /// shared editor points back at whichever list opened it.
    let backTitle: String
    let onBack: () -> Void

    @State private var title: String
    @State private var body_: String
    @State private var didDiscard = false
    @StateObject private var recorder = NoteRecorder()

    private let editorBg = Color(hex: 0xFBFBF9)

    init(note: Note, backTitle: String = "Notetaker", onBack: @escaping () -> Void) {
        self.note = note
        self.backTitle = backTitle
        self.onBack = onBack
        _title = State(initialValue: note.title)
        _body_ = State(initialValue: note.body)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    backControl
                    titleField
                    metaRow
                    bodyEditor
                    Spacer(minLength: 90)
                }
                .padding(28)
            }
            floatingBar
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(editorBg)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        )
        .padding(10)
        .onChange(of: title) { _, _ in save() }
        .onChange(of: body_) { _, _ in save() }
        .onChange(of: recorder.pending) { _, chunks in
            guard !chunks.isEmpty else { return }
            for text in chunks { appendTranscript(text) }
            recorder.pending.removeAll()
        }
        .onDisappear {
            recorder.stop()
            discardIfEmpty()
        }
    }

    private func save() {
        store.updateNote(note, title: title, body: body_)
    }

    /// Appends a final transcript chunk to the note body with a separating space.
    private func appendTranscript(_ text: String) {
        if !body_.isEmpty && !body_.hasSuffix(" ") && !body_.hasSuffix("\n") {
            body_ += " "
        }
        body_ += text
    }

    /// Deletes the note if it has no real content, so leaving an untouched
    /// "New note" never leaves an empty row in the list.
    private func discardIfEmpty() {
        guard !didDiscard else { return }
        let emptyTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let emptyBody = body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard emptyTitle && emptyBody else { return }
        didDiscard = true
        store.deleteNote(note)
    }

    // MARK: - Back

    private var backControl: some View {
        Button(action: { recorder.stop(); discardIfEmpty(); onBack() }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                Text(backTitle)
                    .font(.gsMedium(14))
            }
            .foregroundStyle(Color.figTextGrey)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Title

    private var titleField: some View {
        ZStack(alignment: .leading) {
            if title.isEmpty {
                Text("New note")
                    .font(.loraRegular(25))
                    .foregroundStyle(Color.figTextGrey)
            }
            TextField("", text: $title)
                .textFieldStyle(.plain)
                .font(.loraRegular(25))
                .foregroundStyle(Color.figTextPrimary)
        }
    }

    // MARK: - Meta chip row

    private var metaRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text("Today")
                    .font(.gsMedium(12))
                Text("·")
                    .foregroundStyle(Color.figTextGrey)
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                Text("Me")
                    .font(.gsMedium(12))
            }
            .foregroundStyle(Color.figTextGrey)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule().fill(Color.appBg)
            )
            .overlay(Capsule().stroke(Color.figBorder, lineWidth: 0.5))

            ZStack {
                Circle().stroke(Color.figBorder, lineWidth: 0.5).frame(width: 28, height: 28)
                Image(systemName: "plus").font(.system(size: 11)).foregroundStyle(Color.figTextGrey)
            }
        }
    }

    // MARK: - Body editor

    private var bodyEditor: some View {
        ZStack(alignment: .topLeading) {
            if body_.isEmpty {
                Text("Write notes, or press '/' for templates")
                    .font(.gsRegular(16))
                    .foregroundStyle(Color.figTextGrey)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: $body_)
                .font(.gsRegular(16))
                .foregroundStyle(Color.figTextPrimary)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .frame(minHeight: 260)
        }
    }

    // MARK: - Floating bottom bar

    private var floatingBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                recordPill
                askPill
            }
            HStack {
                if recorder.missingKey {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill").font(.system(size: 9, weight: .semibold))
                        Text("Add a Deepgram key in Settings → Keys to record")
                            .font(.gsMedium(11))
                    }
                    .foregroundStyle(Color(hex: 0xB4432B))
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Capsule().fill(Color(hex: 0xFBEDE9)))
                    .overlay(Capsule().stroke(Color(hex: 0xB4432B).opacity(0.3), lineWidth: 0.5))
                } else {
                    HStack(spacing: 4) {
                        Text(recorder.isRecording
                             ? "Recording — transcribing live into your note"
                             : "Always get consent when transcribing others")
                            .font(.gsMedium(11))
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Color.figTextGrey)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.appBg))
                    .overlay(Capsule().stroke(Color.figBorder, lineWidth: 0.5))
                }
                Spacer()
            }
        }
    }

    private var recordPill: some View {
        Button(action: { recorder.toggle() }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color(hex: 0x1B7A4B))
                    .frame(width: 12, height: 12)
                Text(recorder.isRecording ? "Stop" : "Record")
                    .font(.gsSemibold(13))
                    .foregroundStyle(Color.figTextPrimary)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                Capsule().fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            )
            .overlay(Capsule().stroke(Color.figBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var askPill: some View {
        HStack {
            Text("Ask anything")
                .font(.gsRegular(14))
                .foregroundStyle(Color.figTextGrey)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            Capsule().fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        )
        .overlay(Capsule().stroke(Color.figBorder, lineWidth: 0.5))
    }
}

/// Owns the mic capture + Deepgram engine for live transcription into a note.
/// Reuses the exact same `AudioCapture` + `DeepgramEngine` pieces the dictation
/// coordinator uses, but with no text injection — final transcripts are surfaced
/// via `appendedText` for the editor to append to the note body.
@MainActor final class NoteRecorder: ObservableObject {
    @Published var isRecording = false
    /// True when a record was attempted but no Deepgram key is configured, so
    /// the UI can show a hint instead of appearing frozen.
    @Published var missingKey = false
    /// Queue of FINAL transcript chunks awaiting append; the view drains it and
    /// clears it. A queue (not a single slot) so back-to-back finals are never
    /// dropped before the view coalesces its update.
    @Published var pending: [String] = []

    private var engine: TranscriptionEngine?
    private var audio: AudioCapture?

    func toggle() { isRecording ? stop() : start() }

    func start() {
        guard !isRecording else { return }
        let key = Keychain.get("deepgram_api_key") ?? ""
        guard !key.isEmpty else {
            missingKey = true
            AppLog.log("note-record: no Deepgram key — open Settings → Keys. Not recording.")
            return
        }
        missingKey = false
        isRecording = true
        AppLog.log("note-record: started (live mic → Deepgram → note body)")

        // Open the Deepgram websocket first so it's ready by the time PCM flows.
        let e = DeepgramEngine(apiKey: key)
        engine = e
        e.onTranscript = { [weak self] text, isFinal in
            guard isFinal, !text.isEmpty else { return }
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self.pending.append(text)
                AppLog.log("note-record: appended \"\(text)\"")
            }
        }
        Task {
            do { try await e.start() }
            catch { AppLog.log("note-record: engine.start() error — \(error.localizedDescription)") }
        }

        // Request mic access (prompts only if undetermined; returns immediately
        // if already granted), then start capture — so a first-run permission
        // prompt never leaves the button looking stuck with no audio.
        Task { @MainActor in
            let granted = await Permissions.requestMicrophone()
            if !granted {
                AppLog.log("note-record: microphone not authorized — grant it in System Settings → Privacy → Microphone")
            }
            guard self.isRecording else { return }
            let cap = AudioCapture()
            self.audio = cap
            cap.onPCM = { [weak self] d in Task { @MainActor in self?.engine?.send(d) } }
            do { try cap.start() }
            catch { AppLog.log("note-record: AudioCapture.start() error — \(error.localizedDescription)") }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        audio?.stop()
        engine?.finalize()
        engine?.close()
        engine = nil; audio = nil
        AppLog.log("note-record: stopped")
    }
}
