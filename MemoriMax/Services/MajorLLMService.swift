import Foundation

// MARK: - Shared AI debug log (same file the UI's dlog writes)

enum AIDebugLog {
    static func write(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[AITool] \(message)")
        let line = "[\(time)] \(message)\n"
        for path in ["/tmp/memorydebug.log", NSTemporaryDirectory() + "memorydebug.log"] {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8) ?? Data())
                try? handle.close()
                return
            }
            if FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8)) { return }
        }
    }
}

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Structured candidate output (Apple Intelligence, iOS 26+)

@available(iOS 26.0, *)
@Generable
struct WordCandidate {
    @Guide(description: "One Major System phrase: 2-5 words joined by spaces whose word codes concatenated in order equal the target digits")
    var word: String
    @Guide(description: "One short line tying the phrase to the fact being memorized")
    var tie: String
}

@available(iOS 26.0, *)
@Generable
struct CandidateList {
    @Guide(description: "Exactly three candidate phrases, each 2-5 words, each encoding the full target digits")
    var candidates: [WordCandidate]
}

// MARK: - to_words tool (bundled 62k-word phonetic database as a model tool)

@available(iOS 26.0, *)
struct ToWordsTool: Tool {
    let name = "to_words"
    let description = """
    Looks up real Major System words whose consonant codes equal the given \
    digits, from the app's bundled 62,000-word phonetic database. ALWAYS \
    call this with the target digits before suggesting words, and suggest \
    words ONLY from what it returns — never invent words yourself.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The digit string to look up, e.g. 212")
        var digits: String
    }

    func call(arguments: Arguments) async throws -> String {
        let lookup = arguments.digits.filter(\.isWholeNumber)
        guard !lookup.isEmpty else { return "Invalid digits — pass digits like 212." }
        let rows = MajorTools.to_words(lookup, limit: 15)
        AIDebugLog.write("Apple called to_words('\(lookup)') → \(rows.count) row(s): \(rows.prefix(8).map(\.word).joined(separator: ", ")).")
        guard !rows.isEmpty else {
            return "No exact single-word matches for \(lookup) — try shorter chunks of its digits."
        }
        return rows.map(\.word).joined(separator: ", ")
    }
}
#endif

// MARK: - On-device / fallback AI mnemonic generation
//
// Uses Apple Intelligence (FoundationModels) on iOS 26+ when available.
// Otherwise the UI falls back to a copy-paste prompt (see MajorSystem.aiPrompt).

enum MajorLLMService {
    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    static var unavailableReason: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return ""
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return "This device is not eligible for Apple Intelligence."
                case .appleIntelligenceNotEnabled: return "Apple Intelligence is not enabled in Settings."
                case .modelNotReady: return "The on-device model is still downloading."
                @unknown default: return "Apple Intelligence is unavailable."
                }
            }
        }
        #endif
        return "Apple Intelligence requires iOS 26 or later."
    }

    @available(iOS 26.0, *)
    static func generateMnemonic(for digits: String) async throws -> String {
        #if canImport(FoundationModels)
        let instructions = """
        You turn numbers into Major System mnemonics. Mapping: 0=S/Z, 1=T/D/TH, \
        2=N, 3=M, 4=R, 5=L, 6=SH/CH/J/soft-G, 7=K/hard-C/hard-G/Q, 8=F/V/PH, \
        9=P/B. Vowels and W/H/Y are free and carry no value. Always give a \
        word-by-word code breakdown proving the codes match the input digits.
        """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        Convert the number \(digits) into ONE short, vivid, funny mnemonic phrase \
        using valid Major System words. Reply with: 1) the phrase in bold, \
        2) a word-by-word code breakdown, 3) one sentence visualizing the scene.
        """
        let response = try await session.respond(to: prompt)
        return response.content
        #else
        throw NSError(domain: "MajorLLM", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "FoundationModels unavailable."])
        #endif
    }

    // MARK: - Candidate words for a user's own fact (text only, no images)

    struct AICandidate: Hashable {
        let word: String
        let tie: String
    }

    /// Asks Apple Intelligence for 3 Major System phrases that TOGETHER
    /// encode the fact's full number. The model MUST call the `to_words`
    /// tool (bundled database) — full digits first, then chunks — and build
    /// phrases only from its results. Callers still re-verify every word,
    /// concatenated, on-device — trust, but verify.
    @available(iOS 26.0, *)
    static func generateCandidates(fact: String, digits: String) async throws -> [AICandidate] {
        #if canImport(FoundationModels)
        let instructions = """
        You build Major System mnemonic PHRASES. Mapping: 0=S/Z, 1=T/D/TH, \
        2=N, 3=M, 4=R, 5=L, 6=SH/CH/J/soft-G, 7=K/hard-C/hard-G/Q, 8=F/V/PH, \
        9=P/B. Vowels and W/H/Y count for nothing and are skipped. You have \
        a tool called to_words that searches a 62,000-word phonetic \
        database. ALWAYS call it with the target digits first, then again \
        with shorter chunks (2-4 digits) as needed. A candidate is a PHRASE \
        of 2-5 words assembled ONLY from words to_words returned; the \
        concatenated consonant codes of its words, in order, must equal the \
        FULL target digits exactly — every digit covered, none missing, \
        none extra. Example: 404 → "grandson ray dive" would be wrong \
        (codes 42-4-1); "razor" alone is right when it spans everything \
        (R-Z-R). The phrase should evoke the fact's meaning. Reply with \
        phrases only.
        """
        let session = LanguageModelSession(tools: [ToWordsTool()], instructions: instructions)
        let prompt = """
        Fact to memorize: "\(fact)". Its number is \(digits). Call to_words \
        with "\(digits)" and with useful chunks of it, then suggest exactly \
        3 phrases (2-5 words each). Every phrase's words together must code \
        to the full \(digits). For each phrase, write a one-line tie to the \
        fact explaining how the pictured scene expresses the fact's meaning.
        """
        let response = try await session.respond(to: prompt, generating: CandidateList.self)
        return response.content.candidates.map { AICandidate(word: $0.word, tie: $0.tie) }
        #else
        throw NSError(domain: "MajorLLM", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "FoundationModels unavailable."])
        #endif
    }

    /// Writes the visual STORY that the image model will illustrate: how
    /// every word of the chosen phrase interacts to express the fact.
    /// Plain text generation — no tools, no schema.
    @available(iOS 26.0, *)
    static func generateStory(fact: String, phrase: String, tie: String) async throws -> String {
        #if canImport(FoundationModels)
        let instructions = """
        You compose one-sentence storyboards for picture-book illustrations. \
        Rules: a single vivid sentence, 15-30 words, present tense, \
        describing a concrete physical scene where ALL of the given objects \
        clearly interact to act out the given meaning. Name every object \
        directly. No dialogue or abstract ideas.
        """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        Meaning to express: "\(fact)". Scene hint: "\(tie)". The mnemonic \
        objects that must appear and interact: "\(phrase)". Write the story \
        sentence only — no quotes, no preamble.
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw NSError(domain: "MajorLLM", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "FoundationModels unavailable."])
        #endif
    }
}
