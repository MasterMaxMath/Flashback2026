import Foundation
import SwiftData

// MARK: - Quiz building blocks
//
// A question is ONE number↔word atom taken from a gallery scene. Facts and
// words are snapshotted so quizzes keep working even if the gallery card is
// later edited or removed; the illustration is looked up live from the store
// (by matching fact), so it stays current and is never duplicated.
//
// Two directions per requirement of real recall:
//   .digitsToWord — "431" → remote   (what does the number sound like?)
//   .wordToDigits — remote → "431"   (what does the word spell?)

struct QuizQuestion: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case digitsToWord
        case wordToDigits
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
        guard let best = attempts.map({ $0.correct }).max() else { return "—" }
        return "\(best)"
    }

    var lastScore: String {
        guard let last = attempts.last else { return "—" }
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

    /// Builds up to `limit` questions from the cards' bindings.
    /// With a seed, the output is reproducible (the daily quiz).
    /// Every multiple-choice question carries exactly FIVE options —
    /// 1 correct + 4 wrong — synthesized from the bundled peg vocabulary
    /// when the user's deck is too small to supply real distractors.
    static func questions(from cards: [GalleryCard], seed: Int? = nil, limit: Int = 8) -> [QuizQuestion] {
        var rng = seed.map(SeededGenerator.init)
            ?? SeededGenerator(seed: Int.random(in: 0 ... Int.max))

        let bindings: [(fact: String, digits: String, word: String)] = cards.flatMap { card in
            card.scene.map { (card.fact, $0.digits, $0.word) }
        }
        guard !bindings.isEmpty else { return [] }

        var out: [QuizQuestion] = []
        let chosen = bindings.shuffled(using: &rng).prefix(limit)
        for (i, binding) in chosen.enumerated() {
            let kind: QuizQuestion.Kind = i % 2 == 0 ? .digitsToWord : .wordToDigits

            let correct: String
            let wrong: [String]
            switch kind {
            case .digitsToWord:
                // 4 wrong words: peg vocabulary words for OTHER digit
                // strings of the same width — the standard method, so the
                // distractors look like every other mnemonic the user met.
                correct = binding.word
                wrong = pegWordDistractors(forDigits: binding.digits, correct: correct, count: 4, using: &rng)
            case .wordToDigits:
                // 4 wrong numbers: same-length strings that never equal the
                // answer (deck digits of other bindings first, then random).
                correct = binding.digits
                wrong = digitDistractors(forDigits: binding.digits, count: 4, using: &rng)
            }

            let options = ([correct] + wrong).shuffled(using: &rng)
            guard let correctIndex = options.firstIndex(of: correct) else { continue }

            out.append(QuizQuestion(
                id: UUID(),
                fact: binding.fact,
                kind: kind,
                digits: binding.digits,
                word: binding.word,
                options: options,
                correctIndex: correctIndex
            ))
        }
        return out
    }

    // MARK: distractor synthesis (always exactly `count` wrong options)

    /// `count` wrong words for a number→word question: look up the bundled
    /// DB for random same-width digit strings (≠ the answer's digits), and
    /// pad with peg-list words when the lookup comes up dry.
    private static func pegWordDistractors(forDigits answerDigits: String,
                                           correct correctWord: String,
                                           count: Int,
                                           using rng: inout SeededGenerator) -> [String] {
        var out: [String] = [correctWord]
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
