import SwiftUI
import SwiftData

// MARK: - Major System slideshow (15 minimal slides, memory-first)
// The reader FEELS the arc: fail to hold bare digits → hold a movie with
// zero training → learn why it worked → learn the ten pairs → decode →
// replay → prove it on a final test. One idea per slide, lots of air.
// Image slots are PlaceholderImageView so art can be dropped in later.

struct MajorIntroView: View {
    private let totalPages = 15
    @State private var page = 0

    @State private var selfTestRevealed = false
    @State private var finalWordsRevealed = false
    @State private var finalDatesRevealed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            VStack(spacing: 0) {
                progressHeader

                TabView(selection: $page) {
                    slideForget.tag(0)
                    slideMovie.tag(1)
                    slideWhyStuck.tag(2)
                    slideChunking.tag(3)
                    slidePayoff.tag(4)
                    slideDigits01.tag(5)
                    slideDigits234.tag(6)
                    slideDigits567.tag(7)
                    slideDigits89.tag(8)
                    slideDates.tag(9)
                    slideRazor.tag(10)
                    slideRemote.tag(11)
                    slideScene.tag(12)
                    slideTest.tag(13)
                    slideSummary.tag(14)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomNav
            }
        }
        .navigationTitle("Major System")
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

    // MARK: - 1: Feel forgetting

    private var slideForget: some View {
        guideScroll(eyebrow: "1 / 15 · START WITH FAILURE") {
            Text("Hold these:\n431 404.")
                .slideTitle()

            Text("Read them once, look away, and count to ten. Then try to say them back.")
                .slideBody()

            PlaceholderImageView(
                label: "ART: digits slipping through open hands",
                icon: "hand.raised"
            )

            Text("Gone or fuzzy? That is not a bad memory — bare digits fade for everyone. This guide fixes exactly that.")
                .slideBody()
        }
    }

    // MARK: - 2: Feel remembering (zero training)

    private var slideMovie: some View {
        guideScroll(eyebrow: "2 / 15 · NOW THIS INSTEAD") {
            Text("A razor\nchases a remote.")
                .slideTitle()

            PlaceholderImageView(
                label: "SCENE ART: a giant razor dueling a game remote",
                icon: "film.stack"
            )

            Text("Play that ten-second movie once: a giant buzzing razor chases a game remote across a table. Sparks fly.")
                .slideBody()

            Text("At the end of this guide I will ask you for those two dates again. You have learned nothing yet — notice how little effort this took.")
                .slideFootnote()
        }
    }

    // MARK: - 3: Why the movie stuck (the memory tie-in)

    private var slideWhyStuck: some View {
        guideScroll(eyebrow: "3 / 15 · WHY THAT WORKED") {
            Text("Your memory\nkeeps movies.")
                .slideTitle()

            VStack(alignment: .leading, spacing: 14) {
                plainRow(title: "Digits have nothing to hold", text: "431 404 is abstract — your memory drops it within seconds.")
                plainRow(title: "A chase has everything", text: "Big, strange, moving things with sound and motion are what memory is built to keep.")
                plainRow(title: "The trick", text: "Hide each date inside one word, then let the words act out one scene. You replay the scene — the dates come along for free.")
            }
            .padding(24).cardStyle()

            Text("Everything from here is just the mechanics of hiding digits inside words.")
                .slideFootnote()
        }
    }

    // MARK: - 4: How a word holds digits

    private var slideChunking: some View {
        guideScroll(eyebrow: "4 / 15 · HOW A WORD HOLDS DIGITS") {
            Text("Words spell\nnumbers.")
                .slideTitle()

            VStack(alignment: .leading, spacing: 12) {
                codeBreakdown(word: "moon",
                              pairs: [("m", "3"), ("o", "–"), ("o", "–"), ("n", "2")])
                Text("Read left to right. The counting sounds hand you digits in order — moon hands you 3, then 2. Vowels glide by and give nothing.")
                    .font(.body).foregroundColor(.white.opacity(0.85)).lineSpacing(4)
            }
            .padding(24).cardStyle()

            Text("To hide your own dates this way you need ten pairs — they are next, and they are the only thing to memorize.")
                .slideFootnote()
        }
    }

    // MARK: - 5: The map (movie decoded)

    private var slidePayoff: some View {
        guideScroll(eyebrow: "5 / 15 · YOUR MOVIE, DECODED") {
            Text("The chase you hold\nis two dates.")
                .slideTitle()

            VStack(spacing: 14) {
                payoffRow(digits: "431", word: "remote")
                payoffRow(digits: "404", word: "razor")
            }

            Text("The Peloponnesian wars ran 431 to 404 — the exact numbers that slipped away on page one. Same information, but now it lives inside a chase you can replay.")
                .slideBody()
        }
    }

    // MARK: - 6: Digits 0-1

    private var slideDigits01: some View {
        guideScroll(eyebrow: "6 / 15 · THE TEN PAIRS") {
            Text("Start here:\n0 and 1.")
                .slideTitle()

            Text("Each number always goes with the same sounds. Say each pair out loud once.")
                .slideFootnote()

            VStack(spacing: 14) {
                tableRow(MajorSystem.mappings[0])
                tableRow(MajorSystem.mappings[1])
            }
        }
    }

    // MARK: - 7: Digits 2-3-4

    private var slideDigits234: some View {
        guideScroll(eyebrow: "7 / 15 · KEEP GOING") {
            Text("2, 3 and 4.")
                .slideTitle()

            VStack(spacing: 14) {
                tableRow(MajorSystem.mappings[2])
                tableRow(MajorSystem.mappings[3])
                tableRow(MajorSystem.mappings[4])
            }

            Text("Hooks: N has 2 humps, M has 3, and R ends fouR.")
                .slideFootnote()
        }
    }

    // MARK: - 8: Digits 5-6-7

    private var slideDigits567: some View {
        guideScroll(eyebrow: "8 / 15 · HALFWAY") {
            Text("5, 6 and 7.")
                .slideTitle()

            VStack(spacing: 14) {
                tableRow(MajorSystem.mappings[5])
                tableRow(MajorSystem.mappings[6])
                tableRow(MajorSystem.mappings[7])
            }
        }
    }

    // MARK: - 9: Digits 8-9

    private var slideDigits89: some View {
        guideScroll(eyebrow: "9 / 15 · LAST TWO") {
            Text("Just 8 and 9.")
                .slideTitle()

            VStack(spacing: 14) {
                tableRow(MajorSystem.mappings[8])
                tableRow(MajorSystem.mappings[9])
            }

            Text("That is all ten — the alphabet behind the chase you are already holding.")
                .slideFootnote()

            NavigationLink(destination: MajorCheatSheetView()) {
                Text("Full cheatsheet with hints")
                    .font(.subheadline.bold()).foregroundColor(.white.opacity(0.85))
            }
        }
    }

    // MARK: - 10: Dates

    private var slideDates: some View {
        guideScroll(eyebrow: "10 / 15 · BACK TO THE DATES") {
            Text("Two dates,\none war.")
                .slideTitle()

            PlaceholderImageView(
                label: "ART: timeline showing 431 to 404 BC",
                icon: "calendar"
            )

            Text("Read each word the way moon taught you, using your ten pairs, and watch the digits fall out.")
                .slideBody()
        }
    }

    // MARK: - 11: razor

    private var slideRazor: some View {
        guideScroll(eyebrow: "11 / 15 · READ IT YOURSELF") {
            Text("404 lives\nin razor.")
                .slideTitle()

            VStack(alignment: .leading, spacing: 12) {
                codeBreakdown(word: "razor",
                              pairs: [("r", "4"), ("a", "–"), ("z", "0"), ("o", "–"), ("r", "4")])
                Text("R is 4, Z is 0, R is 4. Glide over the A and the O — the date reads out in order.")
                    .font(.body).foregroundColor(.white.opacity(0.85)).lineSpacing(4)
            }
            .padding(24).cardStyle()
        }
    }

    // MARK: - 12: remote + check

    private var slideRemote: some View {
        guideScroll(eyebrow: "12 / 15 · ONE MORE") {
            Text("431 lives\nin remote.")
                .slideTitle()

            VStack(alignment: .leading, spacing: 12) {
                codeBreakdown(word: "remote",
                              pairs: [("r", "4"), ("e", "–"), ("m", "3"), ("o", "–"), ("t", "1"), ("e", "–")])
                Text("R is 4, M is 3, T is 1. Glide over the vowels.")
                    .font(.body).foregroundColor(.white.opacity(0.85)).lineSpacing(4)
            }
            .padding(24).cardStyle()

            Button(selfTestRevealed ? "razor gives 4 – 0 – 4" : "Check yourself: what does razor give?") {
                selfTestRevealed.toggle()
            }
            .font(.subheadline.bold()).foregroundColor(.black)
            .frame(maxWidth: .infinity).padding(14)
            .background(selfTestRevealed ? Color.green : Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - 13: Scene replay

    private var slideScene: some View {
        guideScroll(eyebrow: "13 / 15 · REPLAY IT") {
            Text("Run the chase\none more time.")
                .slideTitle()

            PlaceholderImageView(
                label: "SCENE ART: a giant razor dueling a game remote",
                icon: "film.stack"
            )

            Text("Same movie as page two, now with meaning attached: the chaser is 404, the chased is 431. This replay is what locks both dates in.")
                .slideBody()
        }
    }

    // MARK: - 14: Final test (the proof)

    private var slideTest: some View {
        guideScroll(eyebrow: "14 / 15 · PROVE IT") {
            Text("No peeking.\nSay them back.")
                .slideTitle()

            Text("Look away from the screen. Which two words chased each other — and which dates do they give you?")
                .slideBody()

            Button(finalWordsRevealed ? "razor and remote" : "Reveal the two words") {
                finalWordsRevealed.toggle()
            }
            .font(.subheadline.bold()).foregroundColor(.black)
            .frame(maxWidth: .infinity).padding(14)
            .background(finalWordsRevealed ? Color.green : Color.white)
            .cornerRadius(12)

            Button(finalDatesRevealed ? "431 and 404" : "Reveal the two dates") {
                finalDatesRevealed.toggle()
            }
            .font(.subheadline.bold()).foregroundColor(.black)
            .frame(maxWidth: .infinity).padding(14)
            .background(finalDatesRevealed ? Color.green : Color.white)
            .cornerRadius(12)

            Text("If both came back, you just felt the whole method: the scene survived where bare digits died on page one.")
                .slideFootnote()
        }
    }

    // MARK: - 15: Summary

    private var slideSummary: some View {
        guideScroll(eyebrow: "15 / 15 · KEEP THIS LOOP") {
            Text("Three steps,\nforever.")
                .slideTitle()

            VStack(spacing: 12) {
                pipeStep(n: "1", title: "Number into a word", color: .blue)
                pipeStep(n: "2", title: "Words into one movie", color: .green)
                pipeStep(n: "3", title: "Movie back into digits", color: .orange)
            }

            NavigationLink(destination: MajorGeneratorView()) {
                Text("Build mine")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.white).cornerRadius(14)
            }
            .padding(.top, 8)

            NavigationLink(destination: MajorCheatSheetView()) {
                Text("Review the cheatsheet")
                    .font(.subheadline.bold()).foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Shared components

    private func guideScroll<Content: View>(eyebrow: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Text(eyebrow).font(.caption.monospaced()).foregroundColor(.white.opacity(0.6))
                content()
            }
            .padding(.horizontal, 32).padding(.vertical, 20).padding(.bottom, 10)
        }
    }

    private func plainRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundColor(.white)
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.85)).lineSpacing(3)
        }
    }

    private func payoffRow(digits: String, word: String) -> some View {
        HStack {
            Text(digits).font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Text("→").foregroundColor(.white.opacity(0.4))
            Text(word).font(.title2.bold()).foregroundColor(.white)
            Spacer()
        }
        .padding(18).cardStyle()
    }

    private func tableRow(_ m: MajorMapping) -> some View {
        HStack(spacing: 16) {
            Text(m.digit)
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 52, height: 52)
                .background(Color.white)
                .cornerRadius(14)
            VStack(alignment: .leading, spacing: 3) {
                Text(m.sounds).font(.headline).foregroundColor(.white)
                Text(m.examples).font(.caption).foregroundColor(.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(16).cardStyle()
    }

    private func pipeStep(n: String, title: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Text(n).font(.headline).foregroundColor(.white)
                .frame(width: 32, height: 32).background(color).cornerRadius(16)
            Text(title).font(.headline).foregroundColor(.white)
            Spacer()
        }
        .padding(18).cardStyle()
    }

    private func codeBreakdown(word: String, pairs: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(word).font(.title2.monospaced().bold()).foregroundColor(.white)
            HStack(spacing: 8) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 3) {
                        Text(pair.0).font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(pair.1 == "–" ? .white.opacity(0.45) : .white)
                            .strikethrough(pair.1 == "–")
                        Text(pair.1).font(.caption2.monospaced())
                            .foregroundColor(pair.1 == "–" ? .white.opacity(0.35) : .green)
                    }
                    .frame(minWidth: 30)
                    .padding(.vertical, 8).padding(.horizontal, 2)
                    .background(pair.1 == "–" ? Color.white.opacity(0.04) : Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                NavigationLink(destination: MajorGeneratorView()) {
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
    func slideTitle() -> some View {
        self.font(.system(size: 32, weight: .black)).foregroundColor(.white)
            .multilineTextAlignment(.center).lineSpacing(4)
            .padding(.top, 16).padding(.bottom, 4)
    }
    func slideBody() -> some View {
        self.font(.body).foregroundColor(.white.opacity(0.88))
            .multilineTextAlignment(.center).lineSpacing(6)
            .padding(.horizontal, 4)
    }
    func slideFootnote() -> some View {
        self.font(.subheadline).foregroundColor(.white.opacity(0.65))
            .multilineTextAlignment(.center).lineSpacing(4)
            .padding(.horizontal, 4)
    }
}

// MARK: - Image placeholder (swap for Image("name") when art is ready)

struct PlaceholderImageView: View {
    let label: String
    var icon: String = "photo"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 30)).foregroundColor(.white.opacity(0.7))
            Text("IMAGE SLOT").font(.caption2.monospaced()).foregroundColor(.white.opacity(0.5))
            Text(label).font(.caption).foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center).padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity).frame(minHeight: 170)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .foregroundColor(.white.opacity(0.35))
        )
        .accessibilityLabel("Placeholder image: \(label)")
    }
}

// MARK: - Small style helpers

extension View {
    func cardStyle() -> some View {
        self.background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15)))
    }
}

#Preview {
    NavigationStack { MajorIntroView() }
        .modelContainer(for: GalleryCard.self, inMemory: true)
}
