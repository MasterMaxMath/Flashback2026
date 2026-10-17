import SwiftUI
import SwiftData

// MARK: - Practice hub
//
// Replaces the old "Grateful Page" menu entry. From here the user picks how
// they want to practice recall: a fresh Daily Quiz, or quizzes they saved
// themselves. Both destinations are placeholders for now — the screens exist
// and are styled, the quiz content comes next.

// MARK: Hub (menu entry)

struct PracticeScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("PRACTICE")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    GradientNavLink(title: "Daily Quiz", destination: DailyQuizScreen())
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

// MARK: Daily quiz (stub)

struct DailyQuizScreen: View {
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's quiz is being prepared.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.9))
                        Text("It will pull scenes from your gallery — the ones you struggle with most come back first.")
                            .font(.caption).foregroundColor(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding().cardStyle()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Daily Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: Saved quizzes (stub)

struct YourQuizzesScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR QUIZZES")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nothing here yet.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.9))
                        Text("Quizzes you build from your gallery groups will appear here, ready to retake any time.")
                            .font(.caption).foregroundColor(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding().cardStyle()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Your Quizzes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { PracticeScreen() }
        .modelContainer(for: GalleryCard.self, inMemory: true)
}
