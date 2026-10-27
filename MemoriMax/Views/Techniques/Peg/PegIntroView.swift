import SwiftUI

// MARK: - Peg System intro (5 minimal slides)
//
// Mirrors the Memory Palace guide: feel the failure, meet the fixed pegs,
// hang an image, walk the numbers, then build.

struct PegIntroView: View {
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
                    slideFixedPegs.tag(1)
                    slideHangImage.tag(2)
                    slideWalk.tag(3)
                    slideBuild.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomNav
            }
        }
        .navigationTitle("Peg System")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

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

    private var slideNoNumber: some View {
        pegScroll(eyebrow: "1 / 5 · START WITH FAILURE") {
            Text("Lists have\nno number.")
                .pegTitle()

            Text("A shopping list, the parts of a speech, the planets in order. Without a hook, the middle items fall out.")
                .pegBody()

            ArtworkImageView(
                name: "torn-grocery-bag",
                accessibility: "Items slipping out of a torn shopping bag"
            )
        }
    }

    private var slideFixedPegs: some View {
        pegScroll(eyebrow: "2 / 5 · FIXED PEGS") {
            Text("Borrow one word\nfor every number.")
                .pegTitle()

            VStack(alignment: .leading, spacing: 10) {
                pegRow(code: "00", word: "sauce")
                pegRow(code: "01", word: "suit")
                pegRow(code: "43", word: "ram")
            }
            .padding(24).cardStyle()

            Text("Learn the 00–99 words once. The number always hands you the same picture.")
                .pegFootnote()
        }
    }

    private var slideHangImage: some View {
        pegScroll(eyebrow: "3 / 5 · HANG AN IMAGE") {
            Text("Put the item\non the peg.")
                .pegTitle()

            Text("Peg 43 is a ram. To remember “buy milk”, picture a ram headbutting a giant milk bottle.")
                .pegBody()

            Text("Big, strange, moving: the same rule as a memory palace.")
                .pegFootnote()
        }
    }

    private var slideWalk: some View {
        pegScroll(eyebrow: "4 / 5 · WALK THE NUMBERS") {
            Text("Count up to\nrecall in order.")
                .pegTitle()

            Text("Walk the pegs in number order: 00 sauce, 01 suit, 43 ram. Each fixed word hands you the item hanging on it.")
                .pegBody()
        }
    }

    private var slideBuild: some View {
        pegScroll(eyebrow: "5 / 5 · BUILD YOURS") {
            Text("Ready to\nbuild one?")
                .pegTitle()

            NavigationLink(destination: PegListView()) {
                Text("Build my peg list")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.white).cornerRadius(14)
            }
            .padding(.top, 8)

            NavigationLink(destination: PegGeneratorView()) {
                Text("Practice 00–99 peg words")
                    .font(.subheadline.bold()).foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func pegScroll<Content: View>(eyebrow: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Text(eyebrow).font(.caption.monospaced()).foregroundColor(.white.opacity(0.6))
                content()
            }
            .padding(.horizontal, 32).padding(.vertical, 20).padding(.bottom, 10)
        }
    }

    private func pegRow(code: String, word: String) -> some View {
        HStack(spacing: 12) {
            Text(code)
                .font(.caption.monospaced()).foregroundColor(.black)
                .frame(width: 38, height: 26)
                .background(RainbowGradient()).cornerRadius(7)
            Text(word).font(.headline).foregroundColor(.white)
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
                NavigationLink(destination: PegListView()) {
                    Text("Build mine").foregroundColor(.black).bold()
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white).cornerRadius(20)
                }
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 16)
    }
}

private extension Text {
    func pegTitle() -> some View {
        self.font(.system(size: 32, weight: .black)).foregroundColor(.white)
            .multilineTextAlignment(.center).lineSpacing(4)
            .padding(.top, 16).padding(.bottom, 4)
    }
    func pegBody() -> some View {
        self.font(.body).foregroundColor(.white.opacity(0.88))
            .multilineTextAlignment(.center).lineSpacing(6)
            .padding(.horizontal, 4)
    }
    func pegFootnote() -> some View {
        self.font(.subheadline).foregroundColor(.white.opacity(0.65))
            .multilineTextAlignment(.center).lineSpacing(4)
            .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack { PegIntroView() }
        .demoModelContainer()
}
