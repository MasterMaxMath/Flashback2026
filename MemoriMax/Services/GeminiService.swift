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
    /// The model MUST call the `to_words` function (executed locally
    /// against the bundled database) and pick only from its results.
    /// Results are still re-checked by callers — trust, but verify.
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
        9=P/B. Vowels and W/H/Y count for nothing and are skipped. You have \
        a function called to_words that searches a 62,000-word phonetic \
        database. ALWAYS call to_words with the target digits before \
        answering, and suggest words ONLY from what it returns. Reply with \
        single words only, never phrases.
        """
        let prompt = """
        Fact to memorize: "\(fact)". Its number is \(digits). Call to_words \
        with digits "\(digits)", then reply with exactly 3 single words from \
        its results. For each word, write a one-line tie to the fact \
        explaining why it fits.
        """
        let toWordsDecl: [String: Any] = [
            "name": "to_words",
            "description": "Looks up real Major System words whose consonant codes equal the given digits, from a 62,000-word phonetic database. ALWAYS call this with the target digits before suggesting words; only suggest words it returns.",
            "parameters": [
                "type": "OBJECT",
                "properties": [
                    "digits": ["type": "STRING", "description": "The digit string to look up, e.g. 212"],
                    "limit": ["type": "INTEGER", "description": "Max words to return (default 15)"]
                ],
                "required": ["digits"]
            ]
        ]

        // Turn 1: force a function call (mode ANY = the model MUST call to_words).
        let turn1: [String: Any] = [
            "system_instruction": ["parts": [["text": instructions]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "tools": [["functionDeclarations": [toWordsDecl]]],
            "toolConfig": ["functionCallingConfig": ["mode": "ANY"]]
        ]
        let parts1 = try await postToGemini(url: url, key: key, body: turn1)

        // Find the to_words call and execute it locally against the bundled DB.
        var calledDigits: String? = nil
        var calledLimit = 15
        for part in parts1 {
            guard let fc = part["functionCall"] as? [String: Any],
                  (fc["name"] as? String) == "to_words" else { continue }
            let args = fc["args"] as? [String: Any] ?? [:]
            calledDigits = args["digits"] as? String
            if let lim = args["limit"] as? Int { calledLimit = lim }
            else if let lim = args["limit"] as? Double { calledLimit = Int(lim) }
            break
        }
        guard let lookup = calledDigits, !lookup.isEmpty else {
            // Model dodged the tool despite mode ANY — fall back to parsing
            // its text directly (callers still verify every word).
            AIDebugLog.write("Gemini skipped to_words despite mode ANY — parsing raw text.")
            return try decodeCandidates(from: parts1)
        }
        let rows = MajorTools.to_words(lookup, limit: calledLimit)
        AIDebugLog.write("Gemini called to_words('\(lookup)') → \(rows.count) row(s): \(rows.prefix(8).map(\.word).joined(separator: ", ")).")

        // Turn 2: hand the rows back, demand the final JSON.
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
        let turn2: [String: Any] = [
            "system_instruction": ["parts": [["text": instructions]]],
            "contents": [
                ["role": "user", "parts": [["text": prompt]]],
                ["role": "model", "parts": parts1],
                ["role": "user", "parts": [[
                    "functionResponse": [
                        "name": "to_words",
                        "response": ["words": rows.map(\.word)]
                    ]
                ]]]
            ],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": schema]
        ]
        let parts2 = try await postToGemini(url: url, key: key, body: turn2)
        return try decodeCandidates(from: parts2)
    }

    /// POSTs one turn and returns the response's content parts.
    private static func postToGemini(url: URL, key: String, body: [String: Any]) async throws -> [[String: Any]] {
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
        return parts
    }

    /// Decodes the `{candidates: [{word, tie}]}` JSON text from parts.
    private static func decodeCandidates(from parts: [[String: Any]]) throws -> [AICandidate] {
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
