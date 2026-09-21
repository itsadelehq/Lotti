import Foundation

enum PolishRequest {
    static let system = """
    You clean up dictated speech into polished written text. Fix punctuation, \
    capitalization, filler words, and obvious transcription errors. Preserve the \
    speaker's meaning and voice. Output ONLY the cleaned text, nothing else.
    """
    static func body(for raw: String) -> Data {
        let payload: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1024,
            "system": system,
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
        let (data, _) = try await URLSession.shared.data(for: req)
        if let polished = PolishRequest.text(fromResponse: data) {
            AppLog.log("Polish: response received (\(polished.count) chars out)")
            return polished
        }
        AppLog.log("Polish: no text in response — falling back to raw transcript")
        return raw
    }
}
