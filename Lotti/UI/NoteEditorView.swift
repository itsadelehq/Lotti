import SwiftUI
import AppKit

/// Full-screen note editor (Figma screen 2). A large serif title field, a meta
/// chip row, a multi-line body editor that autosaves on change, and a bottom
/// floating bar with a live mic-record control (reuses `AudioCapture` +
/// `DeepgramEngine`) plus a cosmetic "Ask anything" pill.
struct NoteEditorView: View {
    @EnvironmentObject var store: Store
    let note: Note
    let onBack: () -> Void

    @State private var title: String
    @State private var body_: String
    @StateObject private var recorder = NoteRecorder()

    private let editorBg = Color(hex: 0xFBFBF9)

    init(note: Note, onBack: @escaping () -> Void) {
        self.note = note
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
        .onChange(of: recorder.appendedText) { _, new in
            guard !new.isEmpty else { return }
            if !body_.isEmpty && !body_.hasSuffix(" ") && !body_.hasSuffix("\n") {
                body_ += " "
            }
            body_ += new
            recorder.appendedText = ""
        }
        .onDisappear { recorder.stop() }
    }

    private func save() {
        store.updateNote(note, title: title, body: body_)
    }

    // MARK: - Back

    private var backControl: some View {
        Button(action: { recorder.stop(); onBack() }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                Text("Notetaker")
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
                HStack(spacing: 4) {
                    Text("Always get consent when transcribing others")
                        .font(.gsMedium(11))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Capsule().fill(Color.appBg))
                .overlay(Capsule().stroke(Color.figBorder, lineWidth: 0.5))
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
    /// Latest final transcript chunk to append; the view consumes and clears it.
    @Published var appendedText: String = ""

    private var engine: TranscriptionEngine?
    private var audio: AudioCapture?

    func toggle() { isRecording ? stop() : start() }

    func start() {
        guard !isRecording else { return }
        let key = Keychain.get("deepgram_api_key") ?? ""
        guard !key.isEmpty else {
            AppLog.log("[Lotti] NoteRecorder: no Deepgram key — open Settings → Keys. Not recording.")
            return
        }
        isRecording = true
        AppLog.log("[Lotti] NoteRecorder: recording started (live mic → Deepgram → note body)")

        let e = DeepgramEngine(apiKey: key)
        engine = e
        e.onTranscript = { [weak self] text, isFinal in
            guard isFinal, !text.isEmpty else { return }
            Task { @MainActor in self?.appendedText = text }
        }
        Task {
            do { try await e.start() }
            catch { AppLog.log("[Lotti] NoteRecorder: engine.start() error — \(error.localizedDescription)") }
        }

        let cap = AudioCapture()
        audio = cap
        cap.onPCM = { [weak self] d in Task { @MainActor in self?.engine?.send(d) } }
        do { try cap.start() }
        catch { AppLog.log("[Lotti] NoteRecorder: AudioCapture.start() error — \(error.localizedDescription)") }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        audio?.stop()
        engine?.finalize()
        engine?.close()
        engine = nil; audio = nil
        AppLog.log("[Lotti] NoteRecorder: recording stopped")
    }
}
