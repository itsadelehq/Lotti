import SwiftUI
import AppKit

/// Snippets — saved voice text-expansion shortcuts. A NAME (spoken trigger)
/// expands to an EXPANSION (text / URL) that gets inserted into a dictation.
/// Rendered inside the white content panel, matching the rest of the app.
struct SnippetsView: View {
    @EnvironmentObject var store: Store

    @State private var items: [Snippet] = []
    @State private var hoveredRow: UUID?

    // Add/Edit modal state.
    @State private var showEditor = false
    @State private var editing: Snippet?          // nil == adding
    @State private var draftName = ""
    @State private var draftExpansion = ""

    private let darkButton = Color(hex: 0x1A1A1A)

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if items.isEmpty {
                        promoCard
                    } else {
                        list
                    }
                }
                .padding(32)
            }
            .task { refresh() }
            .onChange(of: store.revision) { _, _ in refresh() }

            if showEditor {
                editorModal
            }
        }
    }

    private func refresh() { items = store.snippets() }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Snippets")
                .font(.gsBold(30))
                .foregroundStyle(Color.figTextPrimary)
            Spacer()
            addButton(title: "Add new") { beginAdd() }
        }
    }

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.gsMedium(13))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(darkButton))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    // MARK: - Empty state promo card

    private var promoCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("The stuff you shouldn't have to re-type.")
                    .font(.gsBold(22))
                    .foregroundStyle(.white)
                Text("Save text you say often — a link, an intro, a prompt — then say the snippet name to drop it in instantly.")
                    .font(.gsRegular(14))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                exampleChip(name: "my LinkedIn", expansion: "https://linkedin.com/in/adele")
                exampleChip(name: "intro email", expansion: "Hey, would love to…")
            }

            Button(action: { beginAdd() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add new snippet")
                        .font(.gsMedium(13))
                }
                .foregroundStyle(Color(hex: 0x1A1A1A))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .padding(.top, 2)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: 0x1A1A1A)))
    }

    private func exampleChip(name: String, expansion: String) -> some View {
        HStack(spacing: 8) {
            Text("\u{201C}\(name)\u{201D}")
                .font(.gsSemibold(13))
                .foregroundStyle(.white)
            Text("→")
                .font(.gsRegular(13))
                .foregroundStyle(.white.opacity(0.55))
            Text(expansion)
                .font(.gsRegular(13))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.08)))
    }

    // MARK: - Populated list

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, snippet in
                if index > 0 {
                    Rectangle().fill(Color.figBorder).frame(height: 0.5)
                        .padding(.horizontal, 16)
                }
                row(snippet)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.figCardFill))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.figBorder, lineWidth: 0.5))
    }

    private func row(_ snippet: Snippet) -> some View {
        let isHovered = hoveredRow == snippet.id
        return HStack(spacing: 12) {
            Text("\u{201C}\(snippet.name)\u{201D}")
                .font(.gsSemibold(14))
                .foregroundStyle(Color.figTextPrimary)
                .lineLimit(1)
                .layoutPriority(1)
            Text("→")
                .font(.gsRegular(14))
                .foregroundStyle(Color.figTextGrey)
            Text(snippet.expansion)
                .font(.gsRegular(14))
                .foregroundStyle(Color.figTextGrey)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if isHovered {
                iconButton(system: "pencil") { beginEdit(snippet) }
                iconButton(system: "trash") { store.deleteSnippet(snippet) }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
        .onHover { hovering in hoveredRow = hovering ? snippet.id : (hoveredRow == snippet.id ? nil : hoveredRow) }
    }

    private func iconButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.figTextGrey)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(Color.figBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    // MARK: - Add/Edit modal

    private var editorModal: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { showEditor = false }

            editorCard
                .frame(width: 460)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.19), radius: 30, y: 16)
        }
    }

    private var editorCard: some View {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpansion = draftExpansion.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSave = !trimmedName.isEmpty && !trimmedExpansion.isEmpty

        return VStack(alignment: .leading, spacing: 18) {
            Text(editing == nil ? "Add snippet" : "Edit snippet")
                .font(.gsBold(20))
                .foregroundStyle(Color.figTextPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Snippet name")
                    .font(.gsMedium(12))
                    .foregroundStyle(Color.figTextGrey)
                TextField("e.g. my LinkedIn", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.gsRegular(14))
                    .foregroundStyle(Color.figTextPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.figCardFill))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.figBorder, lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Expansion")
                    .font(.gsMedium(12))
                    .foregroundStyle(Color.figTextGrey)
                ZStack(alignment: .topLeading) {
                    if draftExpansion.isEmpty {
                        Text("What should it expand to?")
                            .font(.gsRegular(14))
                            .foregroundStyle(Color.figTextGrey.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $draftExpansion)
                        .font(.gsRegular(14))
                        .foregroundStyle(Color.figTextPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 120)
                }
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.figCardFill))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.figBorder, lineWidth: 0.5))
                HStack {
                    Spacer()
                    Text("\(draftExpansion.count)/4000")
                        .font(.gsRegular(11))
                        .foregroundStyle(Color.figTextGrey.opacity(0.8))
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button(action: { showEditor = false }) {
                    Text("Cancel")
                        .font(.gsMedium(13))
                        .foregroundStyle(Color.figTextPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.figCardFill))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.figBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button(action: { save(name: trimmedName, expansion: trimmedExpansion) }) {
                    Text(editing == nil ? "Add snippet" : "Save")
                        .font(.gsMedium(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(darkButton))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
        }
        .padding(24)
    }

    // MARK: - Actions

    private func beginAdd() {
        editing = nil; draftName = ""; draftExpansion = ""; showEditor = true
    }
    private func beginEdit(_ s: Snippet) {
        editing = s; draftName = s.name; draftExpansion = s.expansion; showEditor = true
    }
    private func save(name: String, expansion: String) {
        let expansion = String(expansion.prefix(4000))
        if let editing {
            store.updateSnippet(editing, name: name, expansion: expansion)
        } else {
            store.addSnippet(name: name, expansion: expansion)
        }
        showEditor = false
    }
}
