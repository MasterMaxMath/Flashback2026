import SwiftUI
import SwiftData
import UIKit

// MARK: - Saved mnemonics gallery (persistent, shared)
//
// Used both as the final step of the assisted flow and as a standalone
// destination from the mode menu. Cards live in SwiftData; art bytes use
// external storage.

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
    }
}

#Preview {
    NavigationStack { GalleryView() }
        .modelContainer(for: GalleryCard.self, inMemory: true)
}
