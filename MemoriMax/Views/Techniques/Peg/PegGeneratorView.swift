import SwiftUI
import SwiftData

// MARK: - Peg System generator
//
// The Peg System gives every number a fixed word (00 sauce, 01 suit, …).
// Enter a number, read its peg story chunk by chunk, and save it to the
// gallery tagged as a Peg System mnemonic so it files under that section.

struct PegGeneratorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var saveTags: SaveTagPresenter
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var gallery: [GalleryCard]

    @State private var input = "431050"
    @State private var fact = ""
    @State private var savedTag: String?

    private var result: MajorSystem.SearchResult { MajorSystem.search(input) }

    private var bindings: [MnemonicBinding] {
        zip(result.chunkCodes, result.chunkedStory).map { code, word in
            MnemonicBinding(digits: code, word: word, tie: "Peg word for \(code)")
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("PEG SYSTEM")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    Text("Hang the digits on fixed peg words, two digits per stop.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.8))

                    numberField

                    if result.digits.isEmpty {
                        Text("Type a number above to see its peg words.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding().cardStyle()
                    } else {
                        pegCard
                        factField
                        saveButton
                        if let savedTag {
                            Text("Saved to “\(savedTag)”.")
                                .font(.caption).foregroundColor(.green.opacity(0.9))
                            NavigationLink(destination: GalleryScreen()) {
                                Text("Open gallery →")
                                    .font(.subheadline.bold()).foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Peg System")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Pieces

    private var numberField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NUMBER").font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
            TextField("e.g. 431050", text: $input)
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3)))
                .onChange(of: input) { _, v in
                    input = MajorSystem.sanitizedDigits(v)
                    savedTag = nil
                }
        }
    }

    private var pegCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR PEG STORY")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))

            Text(result.chunkedStory.joined(separator: "  ·  "))
                .font(.title3.bold()).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(zip(result.chunkCodes, result.chunkedStory)), id: \.0) { pair in
                    HStack(spacing: 10) {
                        Text(pair.0)
                            .font(.caption.monospaced()).foregroundColor(.black)
                            .frame(width: 34, height: 24)
                            .background(RainbowGradient()).cornerRadius(6)
                        Text(pair.1).font(.subheadline.bold()).foregroundColor(.white)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }

    private var factField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT IS IT FOR? (OPTIONAL)")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
            TextField("e.g. My locker combination", text: $fact, axis: .vertical)
                .font(.body).foregroundColor(.white)
                .padding().background(Color.white.opacity(0.1)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3)))
                .lineLimit(1...3)
                .onChange(of: fact) { _, _ in savedTag = nil }
        }
    }

    private var saveButton: some View {
        Button {
            saveTags.present(
                word: result.chunkedStory.joined(separator: " "),
                fact: saveFact,
                existingTags: Array(Set(gallery.map(\.tag))),
                onSave: save
            )
        } label: {
            Label("Save to gallery", systemImage: "square.and.arrow.down")
                .font(.headline).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding(14)
                .background(Color.white).cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(bindings.isEmpty)
    }

    // MARK: - Save

    private var saveFact: String {
        let trimmed = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Peg code for \(result.digits)" : trimmed
    }

    private func save(_ tag: String) {
        guard !bindings.isEmpty else { return }
        modelContext.insert(GalleryCard(
            fact: saveFact,
            bindings: bindings,
            tag: tag,
            imageData: nil,
            technique: MemoryTechnique.peg.rawValue
        ))
        try? modelContext.save()
        savedTag = tag
    }
}

#Preview {
    NavigationStack { PegGeneratorView() }
        .demoModelContainer()
        .environmentObject(SaveTagPresenter())
}
