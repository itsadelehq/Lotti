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
