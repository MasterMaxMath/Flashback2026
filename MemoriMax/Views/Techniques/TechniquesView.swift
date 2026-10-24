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
                        caption: "Turn numbers into words, then words into one scene."
                    ) {
                        MajorIntroView()
                    }

                    technique(
                        title: "Peg System",
                        caption: "Hang any list on the classic 0–99 peg words."
                    ) {
                        PegGeneratorView()
                    }

                    technique(
                        title: "Memory Palace",
                        caption: "Place what you learn along a route you already know."
                    ) {
                        PalaceIntroView()
                    }
                }
                .padding(.horizontal, 50)
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
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GradientNavLink(title: title, destination: destination())
            Text(caption)
                .font(.caption).foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack { TechniquesView() }
        .demoModelContainer()
}
