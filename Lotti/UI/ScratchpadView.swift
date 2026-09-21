import SwiftUI

/// Scratchpad — a single, always-available scratch note. Its text autosaves to
/// `@AppStorage` so it persists across launches. Minimal and on-brand: white
/// panel, Aeonik type.
struct ScratchpadView: View {
    @AppStorage("scratchpadText") private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Scratchpad")
                .font(.gsBold(24))
                .foregroundStyle(Color.figTextPrimary)

            Text("A quick place for stray thoughts. Saved automatically.")
                .font(.gsRegular(14))
                .foregroundStyle(Color.figTextGrey)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Start typing…")
                        .font(.gsRegular(16))
                        .foregroundStyle(Color.figTextGrey)
                        .padding(.top, 12)
                        .padding(.leading, 13)
                }
                TextEditor(text: $text)
                    .font(.gsRegular(16))
                    .foregroundStyle(Color.figTextPrimary)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .padding(6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.figCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.figBorder, lineWidth: 0.5)
            )
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
