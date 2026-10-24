import SwiftUI
import SwiftData

// MARK: - Techniques router
//
// The single entry point for memory techniques. Major System, Peg System and
// Memory Palace each have a guided flow (Views/Major, Views/Techniques/Peg,
// Views/Techniques/Palace). Add a new technique by dropping another
// `technique(...)` row below.

struct TechniquesView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("TECHNIQUES")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    Text("Pick a memory technique to learn.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.8))

                    technique(
                        title: "Major System",
                        caption: "Turn numbers into words, then words into one scene.",
                        systemImage: "number"
                    ) {
                        MajorIntroView()
                    }

                    technique(
                        title: "Peg System",
                        caption: "Hang any list on the classic 0–99 peg words.",
                        systemImage: "list.number"
                    ) {
                        PegIntroView()
                    }

                    technique(
                        title: "Memory Palace",
                        caption: "Place what you learn along a route you already know.",
                        systemImage: "house"
                    ) {
                        PalaceIntroView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Techniques")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - One technique row: card + a short caption underneath

    private func technique<Destination: View>(
        title: String,
        caption: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        GradientNavLink(
            title: title,
            subtitle: caption,
            systemImage: systemImage,
            destination: destination()
        )
    }
}

#Preview {
    NavigationStack { TechniquesView() }
        .demoModelContainer()
}
