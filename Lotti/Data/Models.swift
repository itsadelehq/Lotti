import Foundation
import SwiftData

@Model final class Dictation {
    var id: UUID
    var createdAt: Date
    var rawText: String
    var polishedText: String
    var appBundleId: String?
    var durationSeconds: Double

    init(id: UUID = UUID(), rawText: String, polishedText: String,
         appBundleId: String? = nil, durationSeconds: Double, createdAt: Date = .now) {
        self.id = id; self.rawText = rawText; self.polishedText = polishedText
        self.appBundleId = appBundleId; self.durationSeconds = durationSeconds
        self.createdAt = createdAt
    }
    var wordCount: Int {
        polishedText.split(whereSeparator: { $0.isWhitespace }).count
    }
}

/// A free-form note created in the Notetaker feature. `title` and `body` are
/// edited in the note editor; `updatedAt` is bumped on every save so lists can
/// sort by recency and show relative timestamps.
@Model final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    /// `false` for Notetaker notes, `true` for Scratchpad notes. Both share the
    /// same model and editor; this flag routes them into the right list.
    var isScratch: Bool = false
    /// AI-generated summary (concise summary + optional action items). Empty
    /// until the user taps "Generate summary". New optional-with-default
    /// property so SwiftData migrates the store automatically.
    var summary: String = ""

    init(id: UUID = UUID(), title: String = "", body: String = "",
         isScratch: Bool = false, summary: String = "",
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.body = body
        self.isScratch = isScratch
        self.summary = summary
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

/// A saved voice text-expansion shortcut: the spoken `name` (trigger phrase)
/// is replaced by `expansion` (text/URL) in the dictation transcript.
@Model final class Snippet {
    var id: UUID
    var name: String
    var expansion: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, expansion: String, createdAt: Date = .now) {
        self.id = id; self.name = name; self.expansion = expansion
        self.createdAt = createdAt
    }
}
