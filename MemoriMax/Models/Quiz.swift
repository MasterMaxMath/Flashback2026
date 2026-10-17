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
    static func questions(from cards: [GalleryCard], seed: Int? = nil, limit: Int = 8) -> [QuizQuestion] {
        var rng = seed.map(SeededGenerator.init)
            ?? SeededGenerator(seed: Int.random(in: 0 ... Int.max))

        let bindings: [(fact: String, digits: String, word: String)] = cards.flatMap { card in
            card.scene.map { (card.fact, $0.digits, $0.word) }
        }
        guard !bindings.isEmpty else { return [] }

        let allWords = Array(Set(bindings.map(\.word)))
        let allDigits = Array(Set(bindings.map(\.digits)))

        var out: [QuizQuestion] = []
        let chosen = bindings.shuffled(using: &rng).prefix(limit)
        for (i, binding) in chosen.enumerated() {
            let kind: QuizQuestion.Kind = i % 2 == 0 ? .digitsToWord : .wordToDigits

            let options: [String]
            let correct: String
            switch kind {
            case .digitsToWord:
                correct = binding.word
                let distractors = allWords.filter { $0 != binding.word }.shuffled(using: &rng).prefix(3)
                options = ([correct] + distractors).shuffled(using: &rng)
            case .wordToDigits:
                correct = binding.digits
                var distractors = allDigits.filter { $0 != binding.digits }
                // Pad with digits sounded out from other words (e.g. razor → 404).
                for word in allWords where distractors.count < 3 {
                    let derived = MajorSystem.digits(for: word)
                    let clean = derived.filter(\.isWholeNumber)
                    if clean != correct && !distractors.contains(clean) { distractors.append(clean) }
                }
                let picked = distractors.shuffled(using: &rng).prefix(3)
                options = ([correct] + picked).shuffled(using: &rng)
            }

            out.append(QuizQuestion(
                id: UUID(),
                fact: binding.fact,
                kind: kind,
                digits: binding.digits,
                word: binding.word,
                options: options,
                correctIndex: options.firstIndex(of: correct) ?? 0
            ))
        }
        return out
    }
}
