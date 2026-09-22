import Foundation

enum PolishRequest {
    static let system = """
    You clean up raw dictated speech into clear, correct written text. The input \
    is a speech-to-text transcript that may contain misheard words, missing \
    punctuation, filler, and run-on speech. Fix it — do not rewrite its meaning.

    Do:
    - Fix transcription errors and misheard words/homophones from context \
    (there/their/they're, to/too/two, its/it's, your/you're, then/than, etc.).
    - Correct all capitalisation and punctuation.
    - Remove filler words and phrases (um, uh, like, you know, basically, I mean, \
    sort of), false starts, and accidentally repeated words.
    - Merge rambling, run-on speech into clean, well-formed sentences and \
    paragraphs.
    - Keep technical terms, product names, and brand names intact and correctly \
    formatted (e.g. "web three"/"web 3" → "web3", "chatgpt" → "ChatGPT", \
    "github" → "GitHub", "javascript" → "JavaScript", "i o s" → "iOS").

    Do NOT:
    - Summarise, shorten, expand, or add any content, facts, or commentary.
    - Answer, respond to, or act on the text — you are editing it, not replying.
    - Change the speaker's meaning, wording, intent, or voice beyond the fixes \
    above.
    - Add greetings, sign-offs, quotes, labels, or any preamble.

    Output ONLY the cleaned text — nothing else.
    """
    static func body(for raw: String) -> Data {
        // Scale max_tokens with input length so long dictations aren't truncated.
        // Cleaned output is ~the same length as the input; estimate ~4 chars per
        // token and allow 2x headroom, clamped to a sane [512, 4096] range.
        let estimatedInputTokens = raw.count / 4
        let maxTokens = min(4096, max(512, estimatedInputTokens * 2))
        // Mark the (fixed, reused-every-call) system prompt as cacheable so
        // Anthropic prompt caching skips re-processing it on repeated calls,
        // shaving latency off each polish request.
        let systemBlocks: [[String: Any]] = [
            ["type": "text", "text": system, "cache_control": ["type": "ephemeral"]],
        ]
        let payload: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": maxTokens,
            "system": systemBlocks,
            "messages": [["role": "user", "content": raw]],
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

struct PolishService {
    let apiKey: String
    func polish(_ raw: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = PolishRequest.body(for: raw)
        AppLog.log("Polish: request sent to Claude (\(raw.count) chars in)")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                AppLog.log("Polish: non-200 (\(http.statusCode)) — falling back to raw transcript")
                Toaster.shared.error("AI request failed — check your Anthropic key or connection.")
                return raw
            }
            if let polished = PolishRequest.text(fromResponse: data) {
                AppLog.log("Polish: response received (\(polished.count) chars out)")
                return polished
            }
            AppLog.log("Polish: no text in response — falling back to raw transcript")
            Toaster.shared.error("AI request failed — check your Anthropic key or connection.")
            return raw
        } catch {
            AppLog.log("Polish: request error — \(error.localizedDescription) — falling back to raw transcript")
            Toaster.shared.error("AI request failed — check your Anthropic key or connection.")
            return raw
        }
    }
}
