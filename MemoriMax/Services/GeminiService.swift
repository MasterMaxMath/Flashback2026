import Foundation

// MARK: - Google Gemini candidate words (Option B: dev API key via xcconfig)
//
// Key path: Config/Secrets.xcconfig (gitignored) → $GEMINI_API_KEY → the
// "Sync Gemini Key" build phase writes MemoriMax/Generated/GeminiKey.swift.
// Empty value simply disables this step.
// Model + JSON-schema approach follow the reference google-genai snippet
// (gemini-3.5-flash-lite, application/json), adapted to one-shot REST —
 // no streaming, no thinking block (needless latency for 3 words).

enum GeminiService {
    static let defaultModel = "gemini-3.5-flash-lite"

    struct AICandidate: Hashable {
        let word: String
        let tie: String
    }

    static var apiKey: String {
        GeminiKey.value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var hasKey: Bool { !apiKey.isEmpty && apiKey != "PASTE_KEY_HERE" }

    private struct CandidateJSON: Decodable {
        let word: String
        let tie: String
    }
    private struct ListJSON: Decodable {
        let candidates: [CandidateJSON]
    }

    /// Asks Gemini for 3 single Major words for the fact's number.
    /// Results are NOT trusted — callers must re-check each word with
    /// the bundled database (`MajorTools.digits`) and drop mismatches.
    static func generateCandidates(fact: String, digits: String,
                                   model: String = defaultModel) async throws -> [AICandidate] {
        let key = apiKey
        guard !key.isEmpty else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No Gemini API key configured (Config/Secrets.xcconfig)."
            ])
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw NSError(domain: "Gemini", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Bad Gemini model name: \(model)."
            ])
        }

        let instructions = """
        You turn numbers into Major System words. Mapping: 0=S/Z, 1=T/D/TH, \
        2=N, 3=M, 4=R, 5=L, 6=SH/CH/J/soft-G, 7=K/hard-C/hard-G/Q, 8=F/V/PH, \
        9=P/B. Vowels and W/H/Y count for nothing and are skipped. The \
        consonant codes of each word, read left to right, must equal the \
        target digits exactly. Reply with single words only, never phrases.
        """
        let prompt = """
        Fact to memorize: "\(fact)". Its number is \(digits). Suggest exactly \
        3 single Major System words whose codes equal \(digits). For each word, \
        write a one-line tie to the fact explaining why it fits.
        """
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "candidates": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "word": ["type": "STRING"],
                            "tie": ["type": "STRING"]
                        ],
                        "required": ["word", "tie"]
                    ]
                ]
            ],
            "required": ["candidates"]
        ]
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": instructions]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": schema]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? "unreadable body"
            throw NSError(domain: "Gemini", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Gemini HTTP error: \(String(snippet.prefix(200)))"
            ])
        }

        guard let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cands = outer["candidates"] as? [[String: Any]],
              let content = cands.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw NSError(domain: "Gemini", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Gemini returned an unexpected shape."
            ])
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard let jsonData = text.data(using: .utf8),
              let list = try? JSONDecoder().decode(ListJSON.self, from: jsonData) else {
            throw NSError(domain: "Gemini", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Gemini returned unparseable JSON: \(String(text.prefix(200)))"
            ])
        }
        return list.candidates.map { AICandidate(word: $0.word, tie: $0.tie) }
    }
}
