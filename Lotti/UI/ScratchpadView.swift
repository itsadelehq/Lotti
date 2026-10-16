import SwiftUI
import AppKit

/// Scratchpad — a notes surface for quick, personal thoughts. Mirrors the
/// Notetaker layout (hero banner + a Recents list) but backed by scratch notes
/// (`isScratch == true`) and reusing the same `NoteEditorView`. Selecting or
/// creating a note opens the shared editor; the back control returns here.
struct ScratchpadView: View {
    @EnvironmentObject var store: Store

    @State private var notes: [Note] = []
    @State private var selected: Note?
    @State private var hoveredRow: UUID?


    var body: some View {
        Group {
            if let note = selected {
                NoteEditorView(note: note, backTitle: "Scratchpad", onBack: { selected = nil })
                    .id(note.id)
            } else {
                home
            }
        }
        .task { refresh() }
        .onChange(of: store.revision) { _, _ in refresh() }
    }

    private func refresh() { notes = store.notes(scratch: true) }

    private func openNewNote() {
        let n = store.addNote(scratch: true)
        refresh()
        selected = n
    }

    // MARK: - Home

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                heroCard
                recentsSection
            }
            .padding(32)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Scratchpad")
                .font(.gsBold(24))
                .foregroundStyle(Color.figTextPrimary)
            Text("Beta")
                .font(.gsSemibold(11))
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(Capsule().fill(Color.figCardFill))
                .overlay(Capsule().stroke(Color.figBorder, lineWidth: 0.5))
            Spacer()
        }
    }

    // MARK: - Hero banner

    private var heroCard: some View {
        ZStack(alignment: .leading) {
            BlobGradient()

            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                Text("For quick thoughts you want to come back to")
                    .font(.loraRegular(23))
                    .foregroundStyle(.white)
                Text("Drop a to-do list, polish a message before you send, brain-dump an idea \u{2014} your safe space to save, create, and explore.")
                    .font(.gsRegular(14))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
                Button(action: openNewNote) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Start new note")
                            .font(.gsSemibold(13))
                    }
                    .foregroundStyle(Color.figTextPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(hex: 0xF5F4F1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Recents

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text("Recents")
                    .font(.gsSemibold(12))
                    .foregroundStyle(Color.figTextGrey)
                    .tracking(0.6)
                Spacer()
                Image(systemName: "magnifyingglass")
                Button(action: openNewNote) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                Image(systemName: "eye.slash")
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.figTextGrey)

            if notes.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(notes, id: \.id) { note in
                        noteRow(note)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.figTextGrey)
            Text("No notes found")
                .font(.gsMedium(16))
                .foregroundStyle(Color.figTextGrey)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.figCardFill)
        )
    }

    private func noteRow(_ note: Note) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.appBg)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "note.text")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.figTextGrey)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.gsMedium(15))
                    .foregroundStyle(Color.figTextPrimary)
                    .lineLimit(1)
                Text(previewLine(note))
                    .font(.gsRegular(12))
                    .foregroundStyle(Color.figTextGrey)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { store.deleteNote(note) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.figTextGrey)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.appBg))
            }
            .buttonStyle(.plain)
            .help("Delete note")
            .opacity(hoveredRow == note.id ? 1 : 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hoveredRow == note.id ? Color.figNavHoverBg.opacity(0.5) : Color.figCardFill)
        )
        .contentShape(Rectangle())
        .onTapGesture { selected = note }
        .onHover { hoveredRow = $0 ? note.id : (hoveredRow == note.id ? nil : hoveredRow) }
    }

    private func previewLine(_ note: Note) -> String {
        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return body.isEmpty ? timeString(note.updatedAt) : body
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        fmt.amSymbol = "am"; fmt.pmSymbol = "pm"
        return fmt.string(from: date)
    }
}
