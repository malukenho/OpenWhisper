import Foundation

struct GeminiService {
    private let model = "gemini-2.0-flash-lite"

    func process(text: String, prompt: String, apiKey: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        let fullPrompt = "\(prompt)\n\n\(text)"
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": fullPrompt]]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "unknown error"
            throw GeminiError.apiError(raw)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let resultText = parts.first?["text"] as? String
        else {
            throw GeminiError.unexpectedResponse
        }

        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GeminiError: LocalizedError {
    case invalidURL
    case apiError(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Gemini API URL"
        case .apiError(let msg): return "Gemini API error: \(msg)"
        case .unexpectedResponse: return "Unexpected Gemini API response format"
        }
    }
}
