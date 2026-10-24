import SwiftUI
import SwiftData

// MARK: - Add a stop: pick a saved scene
//
// Presented as a sheet from the builder. Lists every saved scene grouped by
// tag; tapping one returns it to the caller. When nothing is saved yet (or
// the user wants a fresh picture), a link pushes the existing create flow.

struct PalaceScenePicker: View {
    let onPick: (GalleryCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]

    private var groups: [GalleryGroup] { cards.groupedByTag() }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if cards.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No scenes yet.")
                                    .font(.subheadline).foregroundColor(.white.opacity(0.9))
                                Text("A stop is one saved scene. Create one with the Major System, then come back and place it on your route.")
                                    .font(.caption).foregroundColor(.white.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding().cardStyle()
                        } else {
                            ForEach(groups) { group in
                                Text(group.tag.uppercased())
                                    .font(.caption.monospaced()).foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 4)
                                ForEach(group.cards) { card in
                                    pickRow(card)
                                }
                            }
                        }

                        NavigationLink(destination: MajorGeneratorView()) {
                            Label("Create a new scene", systemImage: "plus")
                                .font(.subheadline.bold()).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(14)
                                .background(Color.white.opacity(0.08)).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add a stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func pickRow(_ card: GalleryCard) -> some View {
        Button {
            onPick(card)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                thumbnail(from: card.imageData, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.fact).font(.subheadline).foregroundColor(.white)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    if let first = card.scene.first {
                        HStack(spacing: 6) {
                            Text(first.digits).font(.caption.monospaced()).foregroundColor(.green)
                            Text(first.word).font(.caption.bold()).foregroundColor(.white.opacity(0.85))
                            if card.scene.count > 1 {
                                Text("+\(card.scene.count - 1)")
                                    .font(.caption2).foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.title3).foregroundColor(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).cardStyle()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PalaceScenePicker { _ in }
        .demoModelContainer()
}
