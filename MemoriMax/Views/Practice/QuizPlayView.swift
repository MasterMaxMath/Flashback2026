import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared quiz player
//
// Used by both the Daily Quiz and saved quizzes. One question at a time:
// scene art + fact up top, then answer choices with immediate feedback, then
// a score card. `onFinish` lets saved quizzes record a QuizAttempt (the daily
// quiz is stateless for now).

struct QuizPlayView: View {
    let questions: [QuizQuestion]
    var onFinish: ((QuizAttempt) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var picked: Int?
    @State private var correctCount = 0
    @State private var finished = false
    @State private var art: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if questions.isEmpty {
                        emptyCard
                    } else if finished {
                        scoreCard
                    } else {
                        questionCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: index) { loadArt() }
    }

    // MARK: question

    @ViewBuilder
    private var questionCard: some View {
        let q = questions[index]
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("QUESTION \(index + 1) OF \(questions.count)")
                    .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(correctCount) correct")
                    .font(.caption.monospaced()).foregroundColor(.white.opacity(0.5))
            }

            // Grounding: the scene it came from. For picture questions the
            // art IS the prompt — shown with a neutral border from the
            // start. For every other kind the art is HIDDEN (fully removed
            // — no reserved slot) until the question is answered, then
            // revealed beside the fact as reinforcement.
            if (q.kind == .imageToWord || picked != nil), let art {
                HStack(alignment: .top, spacing: 14) {
                    Image(uiImage: art).resizable().scaledToFill()
                        .frame(width: 110, height: 110).clipped()
                        .cornerRadius(10)
                        .rainbowRim(cornerRadius: 10, active: picked != nil, inactiveColor: Color.white.opacity(0.15))
                    groundingText(q)
                }
            } else {
                groundingText(q)
            }

            Text(stem(q))
                .font(.headline).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                    optionButton(q: q, index: i, option: option)
                }
            }

            if picked != nil {
                Button(nextLabel) { advance() }
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.white).cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }

    @ViewBuilder
    private func optionButton(q: QuizQuestion, index i: Int, option: String) -> some View {
        let isCorrect = i == q.correctIndex
        Button {
            guard picked == nil else { return }
            picked = i
            if isCorrect {
                correctCount += 1
                Haptics.success()
            } else {
                Haptics.error()
            }
        } label: {
            HStack(spacing: 10) {
                Text(option)
                    .font(q.kind == .wordToDigits || q.kind == .factToDigits
                          ? .title3.monospaced() : .headline)
                    .foregroundColor(.white)
                Spacer()
                if picked != nil && isCorrect {
                    Image(systemName: "checkmark.circle.fill").rainbow()
                } else if picked == i && !isCorrect {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { feedbackBackground(isCorrect: isCorrect, mine: picked == i) }
            .cornerRadius(12)
            .rainbowRim(cornerRadius: 12,
                        active: picked != nil && isCorrect,
                        inactiveColor: feedbackStroke(isCorrect: isCorrect, mine: picked == i))
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
        .opacity(picked != nil && !isCorrect && !(picked == i) ? 0.55 : 1)
    }

    /// From the moment an answer is picked: rainbow marks the right choice,
    /// red marks a wrong pick, everything else stays quiet.
    @ViewBuilder
    private func feedbackBackground(isCorrect: Bool, mine: Bool) -> some View {
        if picked == nil {
            Color.white.opacity(0.06)
        } else if isCorrect {
            RainbowGradient().opacity(0.3)
        } else if mine {
            Color.red.opacity(0.2)
        } else {
            Color.white.opacity(0.06)
        }
    }

    private func feedbackStroke(isCorrect: Bool, mine: Bool) -> Color {
        if picked == nil || isCorrect { return Color.white.opacity(0.25) }
        return mine ? Color.red.opacity(0.8) : Color.white.opacity(0.25)
    }

    private var nextLabel: String {
        index + 1 >= questions.count ? "See score" : "Next"
    }

    private func advance() {
        Haptics.tap()
        picked = nil
        if index + 1 >= questions.count { finish() } else { index += 1 }
    }

    private func finish() {
        finished = true
        onFinish?(QuizAttempt(date: Date(), correct: correctCount, total: questions.count))
    }

    // MARK: score

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUIZ COMPLETE")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))

            Text("\(correctCount) / \(questions.count)")
                .font(.system(size: 44, weight: .bold)).foregroundColor(.white)

            Text(scoreMessage)
                .font(.subheadline).foregroundColor(.white.opacity(0.75))

            Button("Done") { dismiss() }
                .font(.headline).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding()
                .background(Color.white).cornerRadius(12)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }

    private var scoreMessage: String {
        let ratio = Double(correctCount) / Double(max(questions.count, 1))
        switch ratio {
        case 1.0: return "Perfect — the scene sticks."
        case 0.8...: return "Strong recall. Almost locked in."
        case 0.5...: return "Halfway there — replay the scenes in the gallery."
        default: return "Shaky — revisit these scenes in the gallery."
        }
    }

    // MARK: empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No questions yet.")
                .font(.subheadline).foregroundColor(.white.opacity(0.9))
            Text("Save mnemonics to the gallery first — quizzes are built from them.")
                .font(.caption).foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }

    // MARK: question text helpers

    /// The grounding block: fact (with numbers redacted whenever the
    /// number is the answer it would leak) plus the number ↔ mnemonic row.
    private func groundingText(_ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(groundingFact(q))
                .font(.subheadline).foregroundColor(.white.opacity(0.9))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if q.kind == .imageToWord && art != nil {
                    // Pure picture round: neither number nor word is shown —
                    // the scene itself must be decoded into its mnemonic.
                    Image(systemName: "photo")
                        .font(.caption).rainbow()
                } else if q.kind == .digitsToWord || q.kind == .factToWord {
                    // The number is given; the mnemonic stays hidden.
                    Text(q.digits).font(.caption.monospaced()).rainbow()
                } else if q.kind == .wordToDigits || q.kind == .factToDigits {
                    // The mnemonic is given; the number stays hidden.
                    Text(q.word).font(.headline).foregroundColor(.white)
                } else {
                    // Picture question whose art went missing (card edited
                    // away?) — degrade to a number question so it stays fair.
                    Text(q.digits).font(.caption.monospaced()).rainbow()
                }
                Text("→").font(.caption).foregroundColor(.white.opacity(0.5))
                Text("?").font(.caption.monospaced()).rainbow()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// When the number itself is the answer, the fact's digits are blanked
    /// out so they can't hand the answer over ("The war ran ____–____ BC").
    private func groundingFact(_ q: QuizQuestion) -> String {
        guard q.kind == .wordToDigits || q.kind == .factToDigits else { return q.fact }
        return Self.blankNumbers(q.fact)
    }

    private static func blankNumbers(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\d+") else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let template = String(repeating: "_", count: 3)
        return regex.stringByReplacingMatches(
            in: text, options: [], range: range,
            withTemplate: template
        )
    }

    /// Question stems. Mnemonics may be phrases ("tea sore bun"), so the
    /// word-direction stems allow for plurality: word(s), encode(s).
    private func stem(_ q: QuizQuestion) -> String {
        switch q.kind {
        case .digitsToWord: return "Which word(s) encode(s) \(q.digits)?"
        case .wordToDigits: return "What number does “\(q.word)” encode?"
        case .factToWord:   return "Which mnemonic goes with this fact?"
        case .factToDigits: return "What number belongs in this fact?"
        case .imageToWord:  return "Which word(s) does this scene depict?"
        }
    }

    // MARK: art

    /// The question snapshot carries the fact; look the illustration up live
    /// so the art always reflects the current card (and is never duplicated).
    private func loadArt() {
        art = nil
        guard !finished, !questions.isEmpty else { return }
        let fact = questions[index].fact
        var descriptor = FetchDescriptor<GalleryCard>(predicate: #Predicate { $0.fact == fact })
        descriptor.fetchLimit = 1
        if let card = try? modelContext.fetch(descriptor).first,
           let data = card.imageData, let image = UIImage(data: data) {
            art = image
        }
    }
}

#Preview("Mid-quiz") {
    NavigationStack {
        QuizPlayView(questions: [
            QuizQuestion(
                id: UUID(),
                fact: "The Peloponnesian War ran 431–404 BC",
                kind: .digitsToWord,
                digits: "431",
                word: "remote",
                options: ["remote", "razor"],
                correctIndex: 0
            )
        ])
    }
    .demoModelContainer()
}
