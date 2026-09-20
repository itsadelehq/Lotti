import Foundation

enum AppCategory: String, CaseIterable {
    case aiTools = "AI Tools", messaging = "Messaging"
    case documents = "Documents", email = "Email", other = "Other"

    static func category(forBundleId id: String?) -> AppCategory {
        guard let id = id?.lowercased() else { return .other }
        let map: [(String, AppCategory)] = [
            ("openai", .aiTools), ("anthropic", .aiTools), ("claude", .aiTools),
            ("chatgpt", .aiTools), ("perplexity", .aiTools),
            ("slack", .messaging), ("discord", .messaging), ("whatsapp", .messaging),
            ("messages", .messaging), ("telegram", .messaging),
            ("mail", .email), ("spark", .email), ("outlook", .email),
            ("pages", .documents), ("word", .documents), ("notion", .documents),
            ("docs", .documents), ("obsidian", .documents), ("textedit", .documents),
        ]
        for (needle, cat) in map where id.contains(needle) { return cat }
        return .other
    }
}
