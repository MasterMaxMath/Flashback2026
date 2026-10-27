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
    static let defaultImageModel = "gemini-3.1-flash-lite-image"

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
        You build Major System mnemonic PHRASES. Mapping: 0=S/Z, 1=T/D/TH, \
        2=N, 3=M, 4=R, 5=L, 6=SH/CH/J/soft-G, 7=K/hard-C/hard-G/Q, 8=F/V/PH, \
        9=P/B. Vowels and W/H/Y count for nothing and are skipped. You have \
        a function called to_words that searches a 62,000-word phonetic \
        database. ALWAYS call to_words with the target digits first, then \
        with shorter chunks (2-4 digits) as needed, and assemble phrases \
        ONLY from words it returned. A candidate is a PHRASE of 2-5 words; \
        the concatenated consonant codes of its words, in order, must equal \
        the FULL target digits exactly — every digit covered, none missing, \
        none extra. Example: 404 → "razor" is right when it spans \
        everything (R-Z-R). The phrase should evoke the fact's meaning. \
        Reply with phrases only, never a word that covers less than the \
        full number. Never use em dashes; use commas or periods instead.
        """
        let prompt = """
        Fact to memorize: "\(fact)". Its number is \(digits). Call to_words \
        with digits "\(digits)" and with useful chunks of it, then reply \
        with exactly 3 phrases (2-5 words each); every phrase's words \
        together must code to the full \(digits). For each phrase, write a \
        one-line tie to the fact explaining how the pictured scene \
        expresses the fact's meaning.
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

        // Tool loop: round 1 forces a call (mode ANY); later rounds allow
        // the model to reason over results and call again, or stop and
        // answer (mode AUTO). Cap at 3 tool rounds, then demand the JSON.
        var contents: [[String: Any]] = [["role": "user", "parts": [["text": prompt]]]]
        let maxToolRounds = 3
        var toolCallsMade = 0
        var lastParts: [[String: Any]] = []
        for round in 1...maxToolRounds {
            let turn: [String: Any] = [
                "system_instruction": ["parts": [["text": instructions]]],
                "contents": contents,
                "tools": [["functionDeclarations": [toWordsDecl]]],
                "toolConfig": ["functionCallingConfig": ["mode": round == 1 ? "ANY" : "AUTO"]]
            ]
            let parts = try await postToGemini(url: url, key: key, body: turn)
            lastParts = parts
            let calls = parts.compactMap { $0["functionCall"] as? [String: Any] }
                .filter { ($0["name"] as? String) == "to_words" }
            if calls.isEmpty {
                AIDebugLog.write("Gemini round \(round): no further tool call — asking for final answer.")
                break
            }
            contents.append(["role": "model", "parts": parts])
            var responses: [[String: Any]] = []
            for call in calls {
                let args = call["args"] as? [String: Any] ?? [:]
                // The model sometimes sends digits as a number — accept both.
                let rawDigits: String
                if let s = args["digits"] as? String { rawDigits = s }
                else if let n = args["digits"] as? Int { rawDigits = String(n) }
                else if let n = args["digits"] as? Double { rawDigits = String(Int(n)) }
                else { rawDigits = "" }
                let lookup = rawDigits.filter(\.isWholeNumber)
                var lim = 15
                if let l = args["limit"] as? Int { lim = l }
                else if let l = args["limit"] as? Double { lim = Int(l) }
                lim = min(max(lim, 1), 30)
                let rows: [ScoredWord] = lookup.isEmpty ? [] : MajorTools.to_words(lookup, limit: lim)
                AIDebugLog.write("Gemini round \(round) to_words('\(lookup)') → \(rows.count) row(s): \(rows.prefix(8).map(\.word).joined(separator: ", ")).")
                toolCallsMade += 1
                responses.append(["functionResponse": [
                    "name": "to_words",
                    "response": ["digits": lookup, "words": rows.map(\.word)]
                ]])
            }
            contents.append(["role": "user", "parts": responses])
        }
        if toolCallsMade == 0 {
            // Mode ANY should guarantee at least one call — parse whatever
            // text came back (callers still verify every word).
            AIDebugLog.write("Gemini skipped to_words despite mode ANY — parsing raw text.")
            return try decodeCandidates(from: lastParts)
        }

        // Final round: no tools declared, strict JSON schema for the answer.
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
        let final: [String: Any] = [
            "system_instruction": ["parts": [["text": instructions]]],
            "contents": contents + [["role": "user", "parts": [["text": """
                Based on the to_words results above, reply with exactly 3 \
                phrases (each 2-5 words, all words from the results or \
                earlier response words; the phrase's words together must \
                code to the full \(digits)) and a one-line tie to the fact \
                for each. The "word" field carries the complete phrase.
                """]]]],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": schema]
        ]
        let finalParts = try await postToGemini(url: url, key: key, body: final)
        return try decodeCandidates(from: finalParts)
    }

    /// Writes the visual STORY the image model will illustrate: one vivid
    /// sentence in which every word of the chosen phrase interacts to act
    /// out the fact. Callers fall back to the tie line when this throws.
    static func generateStory(fact: String, phrase: String, tie: String,
                              model: String = defaultModel) async throws -> String {
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
        You compose one-sentence storyboards for picture-book illustrations. \
        Rules: a single vivid sentence, 15-30 words, present tense, \
        describing a concrete physical scene where ALL of the given objects \
        clearly interact to act out the given meaning. Name every object \
        directly. No dialogue or abstract ideas. Never use em dashes; use \
        commas or periods instead.
        """
        let prompt = """
        Meaning to express: "\(fact)". Scene hint: "\(tie)". The mnemonic \
        objects that must appear and interact: "\(phrase)". Write the story \
        sentence only — no quotes, no preamble.
        """
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": instructions]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]]
        ]
        let parts = try await postToGemini(url: url, key: key, body: body)
        for part in parts {
            if let text = part["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        throw NSError(domain: "Gemini", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Gemini returned no story text."
        ])
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

    // MARK: - Scene illustration (image model, one picture per mnemonic)

    /// Generates one scene illustration (PNG bytes) for the chosen phrase.
    /// Manual trigger from the scene-review step — never per-word, never
    /// automatic — so quota stays under control. Throws code 6 when the
    /// response carries no image (e.g. safety refusal or quota error,
    /// which surfaces earlier as HTTP 429). `story` is the pre-composed
    /// sentence describing how every phrase word interacts.
    static func generateSceneImage(fact: String, phrase: String, story: String,
                                   model: String = defaultImageModel) async throws -> Data {
        let key = apiKey
        guard !key.isEmpty else {
            throw NSError(domain: "Gemini", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No Gemini API key configured (Config/Secrets.xcconfig)."
            ])
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw NSError(domain: "Gemini", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Bad Gemini image model name: \(model)."
            ])
        }
        let prompt = """
        Cheerful children's picture-book illustration. STRICT RULE: absolutely \
        no text, words, letters, numbers, captions, labels, signs, or \
        watermarks anywhere in the image — purely visual, no typography at \
        all. Anything that would normally carry writing (signs, books, \
        labels, posters) must be rendered completely blank. Draw THESE \
        mnemonic objects prominently and unmistakable, each LARGE and easy \
        to point out: \(phrase.phraseWords.map { "\"\($0)\"" }.joined(separator: ", ")). \
        The single scene it must show: \(story). The scene illustrates this \
        fact: "\(fact)". Bold shapes, bright colors, clear silhouettes.
        """
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": ["responseModalities": ["TEXT", "IMAGE"]]
        ]
        let parts = try await postToGemini(url: url, key: key, body: body)
        for part in parts {
            guard let inline = part["inlineData"] as? [String: Any],
                  let b64 = inline["data"] as? String,
                  let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { continue }
            AIDebugLog.write("Gemini image (\(model)) → \(data.count) bytes (\(inline["mimeType"] as? String ?? "?")).")
            return data
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        AIDebugLog.write("Gemini image returned no picture. Text: \(String(text.prefix(160))).")
        throw NSError(domain: "Gemini", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Image model returned no picture\(text.isEmpty ? "." : ": \(String(text.prefix(160)))")"
        ])
    }
}

// MARK: - Prompt helpers

fileprivate extension String {
    /// Splits a mnemonic phrase into its words, for listing in the prompt.
    var phraseWords: [String] { split { $0.isWhitespace }.map(String.init).filter { !$0.isEmpty } }
}
