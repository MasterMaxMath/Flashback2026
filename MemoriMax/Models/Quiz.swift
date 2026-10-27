import Foundation
import SwiftData

// MARK: - Quiz building blocks
//
// A question is ONE recall atom taken from a gallery scene. Facts and
// words are snapshotted so quizzes keep working even if the gallery card is
// later edited or removed; the illustration is looked up live from the store
// (by matching fact), so it stays current and is never duplicated.
//
// FIVE kinds, so every mnemonic gets drilled in more than one way (two
// questions per binding, never the same template twice in a row):
//   .digitsToWord — "431" → remote     (what does the number sound like?)
//   .wordToDigits — remote → "431"     (what does the word spell?)
//   .factToWord   — fact → remote      (which mnemonic belongs to this fact?)
//   .factToDigits — fact (number blanked) → "431" (which number fills the gap?)
//   .imageToWord  — scene art → remote (which picture is which mnemonic?)

struct QuizQuestion: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        /// Number shown, answer is the mnemonic word(s).
        case digitsToWord
        /// Mnemonic word(s) shown, answer is the number.
        case wordToDigits
        /// Fact shown, answer is the mnemonic word(s) belonging to it.
        case factToWord
        /// Fact shown with its numbers blanked, answer is a number.
        case factToDigits
        /// Scene illustration shown, answer is the mnemonic word(s) it depicts.
        case imageToWord
    }

    let id: UUID
    let fact: String
    let kind: Kind
    let digits: String
    let word: String
    /// Answer choices; exactly one matches (correctIndex).
    let options: [String]
    let correctIndex: Int
}

/// One played-through of a quiz.
struct QuizAttempt: Codable, Hashable {
    let date: Date
    let correct: Int
    let total: Int
}

// MARK: - Saved quizzes (persistent)

/// A quiz the user built (currently: from one gallery group — one tag).
@Model
final class SavedQuiz {
    var title: String
    var sourceTag: String
    var questions: [QuizQuestion]      // snapshot at creation; array persists via Codable support
    var createdAt: Date
    var attempts: [QuizAttempt] = []

    init(title: String, sourceTag: String, questions: [QuizQuestion]) {
        self.title = title
        self.sourceTag = sourceTag
        self.questions = questions
        self.createdAt = Date()
    }

    var bestScore: String {
        guard let best = attempts.map({ $0.correct }).max() else { return "None" }
        return "\(best)"
    }

    var lastScore: String {
        guard let last = attempts.last else { return "None" }
        return "\(last.correct)/\(last.total)"
    }
}

// MARK: - Seeded RNG (the day's quiz is the same all day)

/// Small deterministic generator so "today's quiz" is stable for the whole
/// day, and every relaunch shows the same questions until tomorrow.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(truncatingIfNeeded: seed)
        state = state &* 0x9E3779B97F4A7C15 &+ 0x2545F4914F6CDD1D
    }

    mutating func next() -> UInt64 {
        state = state &* 2862933555777941757 &+ 3037000493
        var x = state
        x ^= x >> 33; x &*= 0xff51afd7ed558ccd; x ^= x >> 33
        x ^= x >> 33
        return x
    }
}

// MARK: - Quiz building

enum QuizBuilder {

    /// Day number used to seed the daily quiz (stable all day, new tomorrow).
    static func dayNumber(for date: Date = Date()) -> Int {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let day = cal.ordinality(of: .day, in: .year, for: date) ?? 0
        return year * 1000 + day
    }

    /// Builds up to `limit` questions from the cards' bindings, with TWO
    /// questions per binding (each mnemonic gets drilled more than once,
    /// in different templates). With a seed, the output is reproducible
    /// (the daily quiz). Every multiple-choice question carries exactly
    /// FIVE options — 1 correct + 4 wrong — synthesized from other deck
    /// words, the bundled DB, and the peg vocabulary when those run dry.
    static func questions(from cards: [GalleryCard], seed: Int? = nil, limit: Int = 8) -> [QuizQuestion] {
        var rng = seed.map(SeededGenerator.init)
            ?? SeededGenerator(seed: Int.random(in: 0 ... Int.max))

        /// (fact, digits, word, card has art, other words inside the SAME scene)
        let bindings: [(fact: String, digits: String, word: String, hasArt: Bool, companions: [String])] = cards.flatMap { card in
            let companionWords = card.scene.map(\.word)
            return card.scene.map { (card.fact, $0.digits, $0.word, card.imageData != nil, companionWords) }
        }
        guard !bindings.isEmpty else { return [] }

        let allWords = bindings.map(\.word)
        var out: [QuizQuestion] = []
        // Two questions per mnemonic → ceil(limit / 2) bindings.
        let wanted = Int(ceil(Double(limit) / 2.0))
        for binding in bindings.shuffled(using: &rng).prefix(wanted) {
            // One template asks for the word(s) — the picture round when the
            // scene has art (50/50), otherwise straight or fact-anchored —
            // and one asks for the number — straight, or as the blank in the
            // fact (which is harder: the fact must be recalled without its
            // number leaking through it).
            let wordKind: QuizQuestion.Kind = binding.hasArt && rng.next() % 2 == 0
                ? .imageToWord
                : (rng.next() % 2 == 0 ? .digitsToWord : .factToWord)
            let numberKind: QuizQuestion.Kind = rng.next() % 2 == 0 ? .wordToDigits : .factToDigits
            for kind in [wordKind, numberKind] {
                // Picture questions must not offer the companion words of the
                // SAME scene — e.g. the razor_hits_remote art depicts both
                // razor and remote, so "razor" as a wrong answer for the
                // remote question would be unfair.
                let exclude = kind == .imageToWord ? Set(binding.companions) : Set<String>()
                out.append(makeQuestion(kind: kind, binding: binding,
                                        otherWords: allWords, exclude: exclude, using: &rng))
            }
        }
        return out.shuffled(using: &rng)
    }

    /// Assembles one 5-option question of the given kind.
    private static func makeQuestion(kind: QuizQuestion.Kind,
                                     binding: (fact: String, digits: String, word: String,
                                               hasArt: Bool, companions: [String]),
                                     otherWords: [String],
                                     exclude: Set<String>,
                                     using rng: inout SeededGenerator) -> QuizQuestion {
        let correct: String
        var wrong: [String]
        switch kind {
        case .digitsToWord, .factToWord, .imageToWord:
            // 4 wrong words: other deck mnemonics first (the most realistic
            // wrong answers), then words for random digit probes from the
            // bundled DB, then peg-vocabulary padding.
            correct = binding.word
            wrong = pegWordDistractors(forDigits: binding.digits, correct: binding.word,
                                       others: otherWords, exclude: exclude, count: 4, using: &rng)
        case .wordToDigits, .factToDigits:
            // 4 wrong numbers: same-length strings that never equal the
            // answer (deck digits of other bindings first, then random).
            correct = binding.digits
            wrong = digitDistractors(forDigits: binding.digits, count: 4, using: &rng)
        }
        let options = ([correct] + wrong).shuffled(using: &rng)
        return QuizQuestion(
            id: UUID(),
            fact: binding.fact,
            kind: kind,
            digits: binding.digits,
            word: binding.word,
            options: options,
            correctIndex: options.firstIndex(of: correct) ?? 0
        )
    }

    // MARK: distractor synthesis (always exactly `count` wrong options)

    /// `count` wrong words for a number→word question: other deck mnemonics
    /// first, then lookups of random same-width digit strings (≠ the
    /// answer's digits) in the bundled DB, padded with peg-list words when
    /// the lookup comes up dry.
    private static func pegWordDistractors(forDigits answerDigits: String,
                                           correct correctWord: String,
                                           others: [String] = [],
                                           exclude: Set<String> = [],
                                           count: Int,
                                           using rng: inout SeededGenerator) -> [String] {
        var out: [String] = [correctWord]
        // Real deck words first — the user actually learned them, so they
        // are the most convincing wrong answers (as long as their own
        // codes differ from the answer's digits, they aren't the correct
        // word itself, and they aren't excluded — e.g. same-scene
        // companions on picture questions). Any multi-word phrase here is
        // fine too: candidates are full-number phrases.
        for word in others.shuffled(using: &rng) {
            guard out.count <= count else { break }
            let code = MajorTools.digits(for: word) ?? MajorSystem.digits(for: word)
            if word != correctWord, !exclude.contains(word), code != answerDigits, !out.contains(word) {
                out.append(word)
            }
        }
        var tried: Set<String> = []
        var attempts = 0
        while out.count <= count && attempts < 80 {
            attempts += 1
            let probe = randomDigits(width: answerDigits.count, using: &rng)
            guard probe != answerDigits, !tried.contains(probe) else { continue }
            tried.insert(probe)
            if let word = MajorTools.to_words(probe, limit: 1 + out.count).first?.word {
                out.append(word)
            } else if let word = MajorSystem.search(probe).exact.first {
                out.append(word)
            } else {
                out.append(pegWord(for: probe))
            }
        }
        // Attribute-free tail: peg-list words that are certainly not the
        // answer — not the same word, and not a word encoding the answer's
        // digits (which would be equally correct and thus unfair).
        if out.count <= count {
            for word in MajorSystem.doublePegs.values.shuffled(using: &rng) {
                let code = MajorTools.digits(for: word) ?? MajorSystem.digits(for: word)
                guard !out.contains(word), code != answerDigits else { continue }
                out.append(word)
                if out.count > count { break }
            }
        }
        let wrong = out.dropFirst().filter { word in
            word != correctWord
                && !exclude.contains(word)
                && (MajorTools.digits(for: word) ?? MajorSystem.digits(for: word)) != answerDigits
        }
        let pool = Array(Set(wrong)).shuffled(using: &rng)
        return Array(pool.prefix(count))
    }

    /// `count` wrong numbers for a word→number question: other bindings'
    /// digits first when they fit, then random same-width strings.
    private static func digitDistractors(forDigits answerDigits: String,
                                         count: Int,
                                         using rng: inout SeededGenerator) -> [String] {
        var out: [String] = [answerDigits]
        var attempts = 0
        while out.count <= count && attempts < 40 {
            attempts += 1
            let probe = randomDigits(width: answerDigits.count, using: &rng)
            if probe != answerDigits, !out.contains(probe) {
                out.append(probe)
            }
        }
        return Array(Array(out.dropFirst()).prefix(count))
    }

    /// A random digit string (never all-same digits, for plausibility).
    private static func randomDigits(width: Int, using rng: inout SeededGenerator) -> String {
        var s = ""
        var last = -1
        for _ in 0..<max(width, 1) {
            var d = Int((rng.next() % UInt64(10)))
            if d == last { d = (d + 1 + Int(rng.next() % 9)) % 10 }
            last = d
            s.append(String(d))
        }
        return s
    }

    /// Peg-list words for a digit string when the DB lookup fails: two-digit
    /// chunks through the peg list, odd leftover from single pegs
    /// (e.g. 405 → "sore" + "law").
    private static func pegWord(for digits: String) -> String {
        var words: [String] = []
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(after: index)
            if next < digits.endIndex,
               let two = MajorSystem.doublePegs[String(digits[index...next])] {
                words.append(two)
                index = digits.index(after: next)
            } else if let one = MajorSystem.singlePegs[String(digits[index])] {
                words.append(one)
                index = next
            } else {
                words.append(String(digits[index]))
                index = next
            }
        }
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? digits : joined
    }
}
