import SwiftUI
import AppKit

/// Notetaker — the meeting/notes home. Shows either the home list of notes
/// (hero card, empty-state, day-grouped saved notes) or, when a note is
/// selected, the full-screen `NoteEditorView`. Selection is local `@State`, so
/// switching between list and editor is instant and keeps the sidebar visible.
struct NotetakerView: View {
    @EnvironmentObject var store: Store

    @State private var notes: [Note] = []
    @State private var selected: Note?
    @State private var activeTab: Tab = .past
    @State private var hoveredRow: UUID?

    private enum Tab: String, CaseIterable {
        case past = "Past notes"
        case shared = "Shared with me"
    }

    private let darkButton = Color(red: 0.10, green: 0.10, blue: 0.10)
    private let editorBg = Color(hex: 0xFBFBF9)

    /// A fixed, tasteful preset for the hero banner — reuses the same
    /// `ShaderGradientView`/`ShaderPreset` machinery as the Dictation quote
    /// banner and Snippets promo card.
    private static let heroShaderPreset = shaderPresets[1]

    var body: some View {
        Group {
            if let note = selected {
                NoteEditorView(note: note, onBack: { selected = nil })
                    .id(note.id)
            } else {
                home
            }
        }
        .task { refresh() }
        .onChange(of: store.revision) { _, _ in refresh() }
    }

    private func refresh() { notes = store.notes() }

    private func openNewNote() {
        let n = store.addNote()
        refresh()
        selected = n
    }

    // MARK: - Home

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                heroCard
                todaySection
                tabsRow
                importRow
                notesList
            }
            .padding(32)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Notetaker")
                .font(.gsBold(24))
                .foregroundStyle(Color.figTextPrimary)
            Spacer()
            Button(action: openNewNote) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("New note")
                        .font(.gsSemibold(14))
                }
                .foregroundStyle(Color.figTextPrimary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.appBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.figBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        ZStack(alignment: .leading) {
            // Animated ShaderGradient background (same mechanism as the
            // Dictation quote banner / Snippets promo card), only rendered
            // when the bundled shader page is available.
            if Bundle.main.url(forResource: "quote-shader", withExtension: "html") != nil {
                ShaderGradientView(preset: Self.heroShaderPreset)
            } else {
                Color(red: 0.13, green: 0.12, blue: 0.12)
            }

            // Dark scrim so the light serif title/subtitle stay legible over
            // the bright, high-contrast gradient.
            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                Text("Record your notes when you\u{2019}re on a call")
                    .font(.loraRegular(23))
                    .foregroundStyle(.white)
                Text("Transcript, summary, and action items for every meeting")
                    .font(.gsRegular(14))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - TODAY section (empty state)

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY")
                .font(.gsSemibold(12))
                .foregroundStyle(Color.figTextGrey)
                .tracking(0.6)

            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color.figTextGrey)
                Text("No meetings found")
                    .font(.gsMedium(18))
                    .foregroundStyle(Color.figTextGrey)
                Text("Add calendar for accurate speaker names and richer summaries on all meetings")
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.figTextGrey)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button(action: {}) {
                    Text("Connect calendar")
                        .font(.gsSemibold(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(darkButton)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.figCardFill)
            )
        }
    }

    // MARK: - Tabs

    private var tabsRow: some View {
        HStack(spacing: 20) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { activeTab = tab }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.gsMedium(14))
                            .foregroundStyle(activeTab == tab ? Color.figTextPrimary : Color.figTextGrey)
                        Rectangle()
                            .fill(activeTab == tab ? Color.figTextPrimary : .clear)
                            .frame(height: 1.5)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.figTextGrey)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.figBorder).frame(height: 0.5)
        }
    }

    // MARK: - Import row (cosmetic)

    private var importRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.appBg).frame(width: 40, height: 40)
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.figTextGrey)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Import your meeting notes")
                    .font(.gsMedium(14))
                    .foregroundStyle(Color.figTextPrimary)
                Text("Bring transcripts and summaries from other tools")
                    .font(.gsRegular(12))
                    .foregroundStyle(Color.figTextGrey)
            }
            Spacer()
            Button(action: {}) {
                Text("Skip")
                    .font(.gsMedium(13))
                    .foregroundStyle(Color.figTextGrey)
            }
            .buttonStyle(.plain)
            Button(action: {}) {
                Text("Import")
                    .font(.gsSemibold(13))
                    .foregroundStyle(Color.figTextPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.figBorder, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.figCardFill)
        )
    }

    // MARK: - Saved notes list, grouped by day

    private var notesList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(groupedNotes, id: \.0) { day, dayNotes in
                VStack(alignment: .leading, spacing: 10) {
                    Text(daySectionTitle(day))
                        .font(.gsSemibold(12))
                        .foregroundStyle(Color.figTextGrey)
                        .tracking(0.6)
                    VStack(spacing: 8) {
                        ForEach(dayNotes, id: \.id) { note in
                            noteRow(note)
                        }
                    }
                }
            }
        }
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
                Text("\(timeString(note.createdAt)) · Generate summary")
                    .font(.gsRegular(12))
                    .foregroundStyle(Color.figTextGrey)
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

    // MARK: - Grouping helpers

    private var groupedNotes: [(Date, [Note])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: notes) { cal.startOfDay(for: $0.createdAt) }
        return groups.sorted { $0.key > $1.key }
    }

    private func daySectionTitle(_ day: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let label = fmt.string(from: day).uppercased()
        if cal.isDateInToday(day) { return "TODAY, \(label)" }
        if cal.isDateInYesterday(day) { return "YESTERDAY, \(label)" }
        return label
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        fmt.amSymbol = "am"; fmt.pmSymbol = "pm"
        return fmt.string(from: date)
    }
}
