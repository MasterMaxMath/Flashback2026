import SwiftUI
import SwiftData

// MARK: - Practice hub
//
// Replaces the old "Grateful Page" menu entry. Two ways to practice recall:
// the Daily Quiz (auto-built from the whole gallery, fresh each day) and
// Your Quizzes (persistent quizzes the user builds from a gallery group).

struct PracticeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedQuiz.createdAt, order: .reverse) private var quizzes: [SavedQuiz]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("PRACTICE")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    GradientNavLink(title: "Daily Quiz", destination: DailyQuizScreen())
                        .padding(.bottom, 8)

                    if !quizzes.isEmpty {
                        HStack {
                            Text("YOUR QUIZZES")
                                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(quizzes.count)")
                                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.5))
                        }
                        ForEach(quizzes) { quiz in
                            QuizRow(quiz: quiz) {
                                modelContext.delete(quiz)
                                try? modelContext.save()
                            }
                        }
                    }

                    GradientNavLink(title: "Your Quizzes", destination: YourQuizzesScreen())
                }
                .padding(.horizontal, 50)
                .padding(.vertical, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: Daily Quiz — auto-built for today, deterministic all day

struct DailyQuizScreen: View {
    @Query(sort: \GalleryCard.createdAt) private var cards: [GalleryCard]

    @State private var built = false
    @State private var questions: [QuizQuestion] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("DAILY QUIZ")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.headline).foregroundColor(.white)

                    if cards.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nothing to quiz yet.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Text("Save mnemonics to the gallery first — today's quiz will be built from them.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().cardStyle()
                    } else if questions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView().tint(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding().cardStyle()
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(questions.count) questions, built from your gallery.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Text("Both directions: number → word and word → number. The same set stays up all day; a fresh one arrives tomorrow.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().cardStyle()

                        GradientNavLink(title: "Start today's quiz",
                                        destination: QuizPlayView(questions: questions))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Daily Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            guard !built else { return }
            built = true
            // Seeded by the day number: identical questions until midnight.
            questions = QuizBuilder.questions(from: cards, seed: QuizBuilder.dayNumber(), limit: 8)
        }
    }
}

// MARK: Your Quizzes — user-built, persisted, with score history

struct YourQuizzesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedQuiz.createdAt, order: .reverse) private var quizzes: [SavedQuiz]
    @Query(sort: \GalleryCard.createdAt) private var cards: [GalleryCard]

    @State private var showNewSheet = false

    /// Tag groups available for quiz building, oldest content first ("default" first).
    private var groups: [(tag: String, count: Int)] {
        Dictionary(grouping: cards) { $0.tag.isEmpty ? "default" : $0.tag }
            .map { (tag: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if (lhs.tag == "default") != (rhs.tag == "default") { return lhs.tag == "default" }
                return lhs.tag < rhs.tag
            }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR QUIZZES")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    if quizzes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No quizzes yet.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Text("Build one from any gallery group — it snapshots those mnemonics so you can drill them any time.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().cardStyle()
                    } else {
                        ForEach(quizzes) { quiz in
                            QuizRow(quiz: quiz) {
                                modelContext.delete(quiz)
                                try? modelContext.save()
                            }
                        }
                    }

                    Button {
                        showNewSheet = true
                    } label: {
                        Label("New quiz from a group", systemImage: "plus")
                            .font(.subheadline.bold())
                            .foregroundColor(groups.isEmpty ? .white.opacity(0.4) : .white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                    .disabled(groups.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Your Quizzes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showNewSheet) {
            NewQuizSheet(groups: groups) { tag in
                buildQuiz(from: tag)
            }
        }
    }

    private func buildQuiz(from tag: String) {
        let groupCards = cards.filter { ($0.tag.isEmpty ? "default" : $0.tag) == tag }
        let questions = QuizBuilder.questions(from: groupCards, limit: 10)
        guard !questions.isEmpty else { return }
        let title = tag == "default" ? "My Mnemonics" : tag
        modelContext.insert(SavedQuiz(title: title, sourceTag: tag, questions: questions))
        try? modelContext.save()
    }
}

// MARK: Shared quiz row — listed on both the Practice hub and Your Quizzes

/// A saved quiz rendered as a tappable row: plays the quiz, records the
/// attempt, and offers Remove through the ⋯ menu. `onDelete` does the actual
/// deletion so the owning screen decides (its store, its save).
struct QuizRow: View {
    let quiz: SavedQuiz
    let onDelete: () -> Void

    var body: some View {
        NavigationLink(destination: QuizPlayView(
            questions: quiz.questions,
            onFinish: { attempt in
                quiz.attempts.append(attempt)
                try? quizModelContext.save()
            }
        )) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quiz.title).font(.headline).foregroundColor(.white)
                    Text("\(quiz.questions.count) questions · from \(quiz.sourceTag)")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                    Text(quiz.attempts.isEmpty
                         ? "Not played yet"
                         : "\(quiz.attempts.count) play\(quiz.attempts.count == 1 ? "" : "s") · last \(quiz.lastScore)")
                        .font(.caption).foregroundColor(.green.opacity(0.9))
                }
                Spacer()
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Remove quiz", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(4)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                }
            }
            .padding(12).cardStyle()
        }
        .buttonStyle(.plain)
    }

    /// SwiftData injects a context per view from the environment; rows live
    /// under whichever container the owning screen was presented with.
    @Environment(\.modelContext) private var quizModelContext
}

// MARK: Quiz-creation sheet — pick the group a quiz is built from

struct NewQuizSheet: View {
    let groups: [(tag: String, count: Int)]
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("BUILD A QUIZ")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))

                    Text("Pick a gallery group. Every number↔word pair in it becomes a question, mixed both directions.")
                        .font(.caption).foregroundColor(.white.opacity(0.65))

                    VStack(spacing: 8) {
                        ForEach(groups, id: \.tag) { group in
                            Button {
                                onPick(group.tag)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(group.tag).font(.headline).foregroundColor(.white)
                                        Text("\(group.count) mnemonic\(group.count == 1 ? "" : "s")")
                                            .font(.caption).foregroundColor(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.bold()).foregroundColor(.white.opacity(0.5))
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack { PracticeScreen() }
        .demoModelContainer()
}
