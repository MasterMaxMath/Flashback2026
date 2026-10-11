import SwiftUI
import SwiftData
import UIKit

// MARK: - Saved mnemonics gallery (persistent, shared)
//
// Used both as the final step of the assisted flow and as a standalone
// destination from the mode menu. Cards live in SwiftData; art bytes use
// external storage. `GalleryScreen` adds the app chrome (dark background,
// scrolling, title) for menu entry; the flow embeds `GalleryView` directly.

struct GalleryScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                GalleryView()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
            }
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]

    var body: some View {
        VStack(spacing: 16) {
            Text("GALLERY")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            if cards.isEmpty {
                Text("Nothing saved yet — tap Good on a scene to keep it here, on this device.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center).padding().cardStyle()
            } else {
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.fact).font(.subheadline).foregroundColor(.white.opacity(0.9))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.word).font(.headline).foregroundColor(.white)
                            Text(card.tie).font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10).background(Color.black.opacity(0.4)).cornerRadius(10)
                        if let data = card.imageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable().scaledToFit()
                                .cornerRadius(10)
                        } else {
                            PlaceholderImageView(
                                label: "SAVED ART: \(card.word.lowercased()) scene",
                                icon: "photo"
                            )
                        }
                        Button("Remove", role: .destructive) {
                            modelContext.delete(card)
                            try? modelContext.save()
                        }
                        .font(.caption).foregroundColor(.red.opacity(0.85))
                    }
                    .padding().cardStyle()
                }
            }
        }
        .onAppear { Self.seedIfNeeded(context: modelContext) }
    }

    /// Demo content (tutorial dates). For now these are ALWAYS present:
    /// every visit re-inserts any missing ones, so the gallery never
    /// sits empty during development and judging.
    static func seedIfNeeded(context: ModelContext) {
        let demos = [
            ("The Peloponnesian War began in 431 BC",
             "431", "remote", "Remote lands clashed — 431 opens the war"),
            ("The Peloponnesian War ended in 404 BC",
             "404", "razor", "Decided on a razor's edge — 404 closes the war")
        ]
        let existingFacts = Set((try? context.fetch(FetchDescriptor<GalleryCard>()))?.map(\.fact) ?? [])
        var added = 0
        for (fact, digits, word, tie) in demos where !existingFacts.contains(fact) {
            context.insert(GalleryCard(fact: fact, digits: digits, word: word, tie: tie))
            added += 1
        }
        if added > 0 { try? context.save() }
        AIDebugLog.write("Gallery demo check — re-added \(added) card(s).")
    }
}

#Preview {
    NavigationStack { GalleryScreen() }
        .modelContainer(for: GalleryCard.self, inMemory: true)
}
