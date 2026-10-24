import SwiftUI
import SwiftData

// MARK: - Memory Palace intro (5 minimal slides, memory-first)
//
// Same arc as the Major System guide: feel the failure, feel the fix, learn
// the mechanics, then build. One idea per slide, lots of air.

struct PalaceIntroView: View {
    private let totalPages = 5
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            VStack(spacing: 0) {
                progressHeader

                TabView(selection: $page) {
                    slideNoNumber.tag(0)
                    slidePlaceBeatsList.tag(1)
                    slideOneStop.tag(2)
                    slideWalkBack.tag(3)
                    slideBuild.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomNav
            }
        }
        .navigationTitle("Memory Palace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Progress

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("STEP \(page + 1) OF \(totalPages)")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: Double(page + 1), total: Double(totalPages))
                .tint(.white).opacity(0.9)
        }
        .padding(.horizontal, 32).padding(.top, 10)
    }

    // MARK: - 1: Feel the failure

    private var slideNoNumber: some View {
        palaceScroll(eyebrow: "1 / 5 · START WITH FAILURE") {
            Text("Some things\nhave no number.")
                .palaceTitle()

            Text("A shopping list, the parts of a speech, the planets in order. Bare digits fade — and so does a bare list.")
                .palaceBody()

            PlaceholderImageView(
                label: "ART: items slipping out of a torn shopping bag",
                icon: "list.bullet"
            )
        }
    }

    // MARK: - 2: The place

    private var slidePlaceBeatsList: some View {
        palaceScroll(eyebrow: "2 / 5 · A PLACE BEATS A LIST") {
            Text("You already own\na perfect map.")
                .palaceTitle()

            PlaceholderImageView(
                label: "ART: a friendly floor plan — door, hall, kitchen",
                icon: "house"
            )

            Text("Your home. Your walk to school. Any route you know so well you could take it blindfolded. Memory keeps places for free.")
                .palaceBody()
        }
    }

    // MARK: - 3: One stop, one image

    private var slideOneStop: some View {
        palaceScroll(eyebrow: "3 / 5 · ONE STOP, ONE IMAGE") {
            Text("Leave an image\nat each stop.")
                .palaceTitle()

            VStack(alignment: .leading, spacing: 12) {
                stopRow(location: "Front door", image: "a giant lemon blocks the way")
                stopRow(location: "Hallway", image: "milk floods the floor like a wave")
                stopRow(location: "Kitchen", image: "a loaf of bread bounces off the stove")
            }
            .padding(24).cardStyle()

            Text("Big, strange, moving. The weirder the picture, the harder it is to lose.")
                .palaceFootnote()
        }
    }

    // MARK: - 4: Walk it back

    private var slideWalkBack: some View {
        palaceScroll(eyebrow: "4 / 5 · WALK IT BACK") {
            Text("Retrace your\nsteps to recall.")
                .palaceTitle()

            Text("Walk the same route from the start. The front door hands you the lemon, the lemon hands you \"lemons\". The places keep the order for you.")
                .palaceBody()

            Text("That is the whole trick — and it pairs perfectly with words that hold numbers.")
                .palaceFootnote()
        }
    }

    // MARK: - 5: Build

    private var slideBuild: some View {
        palaceScroll(eyebrow: "5 / 5 · BUILD YOURS") {
            Text("Ready to\nbuild one?")
                .palaceTitle()

            NavigationLink(destination: PalaceListView()) {
                Text("Build my palace")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.white).cornerRadius(14)
            }
            .padding(.top, 8)

            NavigationLink(destination: MajorIntroView()) {
                Text("See how words hold numbers")
                    .font(.subheadline.bold()).foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Shared components

    private func palaceScroll<Content: View>(eyebrow: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Text(eyebrow).font(.caption.monospaced()).foregroundColor(.white.opacity(0.6))
                content()
            }
            .padding(.horizontal, 32).padding(.vertical, 20).padding(.bottom, 10)
        }
    }

    private func stopRow(location: String, image: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title3).foregroundColor(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(location).font(.headline).foregroundColor(.white)
                Text(image).font(.subheadline).foregroundColor(.white.opacity(0.8))
            }
            Spacer()
        }
    }

    private var bottomNav: some View {
        HStack {
            Button("Back") { if page > 0 { withAnimation { page -= 1 } } }
                .disabled(page == 0).foregroundColor(page == 0 ? .gray : .white)
            Spacer()
            HStack(spacing: 5) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle().fill(i == page ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if page < totalPages - 1 {
                HStack(spacing: 18) {
                    Button("Skip") { withAnimation { page = totalPages - 1 } }
                        .foregroundColor(.white.opacity(0.65))
                    Button("Next") { withAnimation { page += 1 } }.foregroundColor(.white).bold()
                }
            } else {
                NavigationLink(destination: PalaceListView()) {
                    Text("Build mine").foregroundColor(.black).bold()
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white).cornerRadius(20)
                }
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 16)
    }
}

// MARK: - Slide typography: one voice, generous air

private extension Text {
    func palaceTitle() -> some View {
        self.font(.system(size: 32, weight: .black)).foregroundColor(.white)
            .multilineTextAlignment(.center).lineSpacing(4)
            .padding(.top, 16).padding(.bottom, 4)
    }
    func palaceBody() -> some View {
        self.font(.body).foregroundColor(.white.opacity(0.88))
            .multilineTextAlignment(.center).lineSpacing(6)
            .padding(.horizontal, 4)
    }
    func palaceFootnote() -> some View {
        self.font(.subheadline).foregroundColor(.white.opacity(0.65))
            .multilineTextAlignment(.center).lineSpacing(4)
            .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack { PalaceIntroView() }
        .demoModelContainer()
}
