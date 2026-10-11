import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Structured candidate output (Apple Intelligence, iOS 26+)

@available(iOS 26.0, *)
@Generable
struct WordCandidate {
    @Guide(description: "One single Major System word whose consonant codes equal the target digits")
    var word: String
    @Guide(description: "One short line tying the word to the fact being memorized")
    var tie: String
}

@available(iOS 26.0, *)
@Generable
struct CandidateList {
    @Guide(description: "Exactly three candidate words")
    var candidates: [WordCandidate]
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

    /// Asks Apple Intelligence for 3 single Major words for the fact's
    /// number, each with a one-line tie to the fact. Results are NOT
    /// trusted blindly — callers must re-check each word with
    /// `MajorSystem.digits(for:)` and drop anything that mismatches.
    @available(iOS 26.0, *)
    static func generateCandidates(fact: String, digits: String) async throws -> [AICandidate] {
        #if canImport(FoundationModels)
        let instructions = """
        You turn numbers into Major System words. Mapping: 0=S/Z, 1=T/D/TH, \
        2=N, 3=M, 4=R, 5=L, 6=SH/CH/J/soft-G, 7=K/hard-C/hard-G/Q, 8=F/V/PH, \
        9=P/B. Vowels and W/H/Y count for nothing and are skipped. The \
        consonant codes of each word, read left to right, must equal the \
        target digits exactly. Reply with single words only, never phrases.
        """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        Fact to memorize: "\(fact)". Its number is \(digits). Suggest exactly \
        3 single Major System words whose codes equal \(digits). For each word, \
        write a one-line tie to the fact explaining why it fits.
        """
        let response = try await session.respond(to: prompt, generating: CandidateList.self)
        return response.content.candidates.map { AICandidate(word: $0.word, tie: $0.tie) }
        #else
        throw NSError(domain: "MajorLLM", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "FoundationModels unavailable."])
        #endif
    }
}
