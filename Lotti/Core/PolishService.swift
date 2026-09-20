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
        let (data, _) = try await URLSession.shared.data(for: req)
        return PolishRequest.text(fromResponse: data) ?? raw
    }
}
