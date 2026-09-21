import Foundation

/// Custom vocabulary the user wants Deepgram to recognise (names, brands,
/// jargon). Stored as a JSON `[String]` in `UserDefaults` under
/// `"customVocabulary"`, so both the Settings UI and the transcription engine
/// read the same single source of truth. Backed by thread-safe `UserDefaults`,
/// so it is safe to read/write from the main actor (the UI) and from the
/// engine-construction closures alike.
enum Vocabulary {
    static let key = "customVocabulary"

    /// Current list of terms, oldest first. Never throws — a missing or corrupt
    /// value decodes to an empty list.
    static func terms() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return list
    }

    /// Persists the terms, trimming blanks and de-duplicating case-insensitively
    /// while preserving order. Encodes as JSON.
    static func set(_ terms: [String]) {
        var seen = Set<String>()
        let cleaned = terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
        if let data = try? JSONEncoder().encode(cleaned) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
