import Foundation

// MARK: - Cloudflare Workers AI scene illustrations
//
// Credentials path: Config/Secrets.xcconfig (gitignored, never committed)
// → $CLOUDFLARE_ACCOUNT_ID + $CLOUDFLARE_API_TOKEN → the "Sync API Keys"
// build phase writes MemoriMax/Generated/CloudflareKey.swift.
// Empty credentials simply disable this step (Gemini image or the
// placeholder slot is used instead).
//
// Token: dash.cloudflare.com → Manage Account → API Tokens → create one
// from the "Workers AI" template. Account ID: dashboard sidebar.

enum CloudflareImageService {
    /// Fast text-to-image model; swap for another Workers AI image model
    /// (e.g. "@cf/stabilityai/stable-diffusion-xl-base-1.0") if desired.
    static let defaultModel = "@cf/black-forest-labs/flux-1-schnell"

    static var accountID: String {
        CloudflareKey.accountID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var token: String {
        CloudflareKey.token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var hasCredentials: Bool {
        !accountID.isEmpty && !token.isEmpty
            && token != "PASTE_TOKEN_HERE" && accountID != "PASTE_ACCOUNT_ID_HERE"
    }

    /// Generates one scene illustration (image bytes) for the chosen
    /// phrase. Workers AI image endpoints return raw image bytes; some
    /// gateways wrap them in a `{result: {image: base64}}` JSON envelope —
    /// both are handled. Manual trigger from scene review only, one picture
    /// per scene. `story` is a pre-composed sentence describing how every
    /// phrase word interacts (task 1 requirement: story before image).
    static func generateSceneImage(fact: String, phrase: String, story: String,
                                   model: String = defaultModel) async throws -> Data {
        guard hasCredentials else {
            throw NSError(domain: "Cloudflare", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No Cloudflare credentials (Config/Secrets.xcconfig)."
            ])
        }
        guard let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountID)/ai/run/\(model)") else {
            throw NSError(domain: "Cloudflare", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Bad Cloudflare model name: \(model)."
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
        // Note: flux models reject unevaluated properties, so there is no
        // negative_prompt field — everything lives in the prompt text.
        let body: [String: Any] = ["prompt": prompt]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Cloudflare", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No HTTP response from Cloudflare."
            ])
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? "unreadable body"
            AIDebugLog.write("Cloudflare image HTTP \(http.statusCode): \(String(snippet.prefix(160))).")
            throw NSError(domain: "Cloudflare", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Cloudflare HTTP \(http.statusCode): \(String(snippet.prefix(160)))"
            ])
        }
        let mime = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        if mime.hasPrefix("image"), !data.isEmpty {
            AIDebugLog.write("Cloudflare image (\(model)) → \(data.count) bytes (\(mime)).")
            return data
        }
        // JSON envelope fallback: {result: {image: "<base64>"}} or {result: "<base64>"}.
        if let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let result = outer["result"] as? [String: Any],
               let b64 = result["image"] as? String,
               let image = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) {
                AIDebugLog.write("Cloudflare image (\(model), envelope) → \(image.count) bytes.")
                return image
            }
            if let b64 = outer["result"] as? String,
               let image = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) {
                AIDebugLog.write("Cloudflare image (\(model), envelope) → \(image.count) bytes.")
                return image
            }
            let snippet = String(data: data, encoding: .utf8) ?? "unreadable body"
            AIDebugLog.write("Cloudflare image: unexpected JSON: \(String(snippet.prefix(200))).")
        }
        throw NSError(domain: "Cloudflare", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Cloudflare returned no picture (content-type: \(mime))."
        ])
    }
}

// MARK: - Prompt helpers

fileprivate extension String {
    /// Splits a mnemonic phrase into its words, for listing in the prompt.
    var phraseWords: [String] { split { $0.isWhitespace }.map(String.init).filter { !$0.isEmpty } }
}
