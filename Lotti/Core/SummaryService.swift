import Foundation

/// Builds and parses the Claude Haiku request used to summarise a note. Mirrors
/// `PolishRequest`'s HTTP shape (same endpoint, headers, model, response parse).
enum SummaryRequest {
    static let system = """
    You summarise a personal note into a short, useful digest.

    Produce:
    - A concise summary of the note in a few plain sentences (or a couple of \
    short bullet points if that reads more clearly).
    - Then, ONLY if the note contains clear tasks, next steps, or commitments, \
    an "Action items" section: the heading "Action items" on its own line, \
    followed by one "- " bullet per action. Omit the section entirely when \
    there are no clear actions.

    Rules:
    - Output plain text / light Markdown (dashes for bullets). No headings \
    other than "Action items", no code fences.
    - No preamble, greetings, sign-offs, or commentary — output ONLY the \
    summary itself.
    - Do not invent facts or actions that are not in the note.
    """
    static func body(for text: String) -> Data {
        // Reuse Anthropic prompt caching for the fixed system prompt so repeat
        // calls skip re-processing it (same approach as PolishRequest).
        let systemBlocks: [[String: Any]] = [
            ["type": "text", "text": system, "cache_control": ["type": "ephemeral"]],
        ]
        let payload: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 700,
            "system": systemBlocks,
            "messages": [["role": "user", "content": text]],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
    static func text(fromResponse data: Data) -> String? {
        struct Resp: Decodable { struct Block: Decodable { let type: String; let text: String? }
            let content: [Block] }
        guard let r = try? JSONDecoder().decode(Resp.self, from: data) else { return nil }
        return r.content.first(where: { $0.type == "text" })?.text
    }
}

struct SummaryService {
    let apiKey: String
    func summarize(_ text: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = SummaryRequest.body(for: text)
        AppLog.log("summary: request sent to Claude (\(text.count) chars in)")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            AppLog.log("summary: request error — \(error.localizedDescription)")
            Toaster.shared.error("AI request failed — check your Anthropic key or connection.")
            throw error
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            AppLog.log("summary: non-200 (\(http.statusCode))")
            Toaster.shared.error("AI request failed — check your Anthropic key or connection.")
            throw NSError(domain: "SummaryService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Summary request failed"])
        }
        if let summary = SummaryRequest.text(fromResponse: data)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            AppLog.log("summary: response received (\(summary.count) chars out)")
            return summary
        }
        AppLog.log("summary: no text in response")
        Toaster.shared.error("AI request failed — check your Anthropic key or connection.")
        throw NSError(domain: "SummaryService", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "No summary returned"])
    }
}
