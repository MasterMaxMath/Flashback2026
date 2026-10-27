import SwiftUI
import SwiftData
import Foundation

// MARK: - Add a peg
//
// Two steps: pick an unused peg from 00–99, then hang either a plain-text item
// or a saved gallery scene on it.

struct PegSlotPicker: View {
    let usedNumbers: Set<String>
    let onAdd: (PegSlot) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]

    @State private var selectedNumber: String?
    @State private var text = ""
    @State private var pickedCard: GalleryCard?

    private var allPegs: [(String, String)] {
        (0...99).map { i in
            let code = String(format: "%02d", i)
            return (code, MajorSystem.doublePegs[code] ?? "?")
        }
    }

    private var word: String {
        guard let number = selectedNumber else { return "" }
        return MajorSystem.doublePegs[number] ?? "?"
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        pickedCard != nil || !trimmedText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if selectedNumber == nil {
                            Text("Pick a peg for the next item. Used pegs are dimmed.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                            pegGrid
                        } else {
                            selectedView
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(selectedNumber.map { "Peg \($0)" } ?? "Add a peg")
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

    // MARK: - Step 1

    private var pegGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
            ForEach(allPegs, id: \.0) { pair in
                let used = usedNumbers.contains(pair.0)
                Button {
                    selectedNumber = pair.0
                    text = ""
                    pickedCard = nil
                } label: {
                    VStack(spacing: 2) {
                        Text(pair.0)
                            .font(.caption.monospaced()).rainbow()
                        Text(pair.1)
                            .font(.caption2).foregroundColor(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(used ? 0.03 : 0.08))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(used ? 0.08 : 0.25)))
                    .opacity(used ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(used)
            }
        }
    }

    // MARK: - Step 2

    private var selectedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PEG \(selectedNumber ?? "")")
                        .font(.caption.monospaced()).rainbow()
                    Text(word)
                        .font(.system(size: 40, weight: .black)).foregroundColor(.white)
                }
                Spacer()
                Button("Change") { selectedNumber = nil }
                    .font(.caption.bold()).foregroundColor(.white.opacity(0.7))
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading).cardStyle()

            TextField("What hangs on this peg?", text: $text, axis: .vertical)
                .font(.body).foregroundColor(.white)
                .padding().background(Color.white.opacity(0.1)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                .lineLimit(1...3)
                .onChange(of: text) { _, _ in
                    if !text.isEmpty { pickedCard = nil }
                }

            Text("OR PICK A SAVED SCENE")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.6))

            if cards.isEmpty {
                Text("No saved scenes yet. Type an item above, or create one later with the Major System.")
                    .font(.caption).foregroundColor(.white.opacity(0.55))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
            } else {
                ForEach(Array(cards.prefix(40))) { card in
                    sceneRow(card)
                }
            }

            Button {
                add()
            } label: {
                Label("Add to peg list", systemImage: "plus")
                    .font(.headline).foregroundColor(canAdd ? .black : .white.opacity(0.4))
                    .frame(maxWidth: .infinity).padding(14)
                    .background(canAdd ? Color.white : Color.white.opacity(0.1))
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
    }

    private func sceneRow(_ card: GalleryCard) -> some View {
        Button {
            pickedCard = card
            text = ""
        } label: {
            HStack(spacing: 12) {
                thumbnail(from: card.imageData, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.fact).font(.subheadline).foregroundColor(.white)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    if let first = card.scene.first {
                        Text("\(first.digits) · \(first.word)")
                            .font(.caption.monospaced()).rainbow()
                    }
                }
                Spacer()
                Image(systemName: pickedCard === card ? "checkmark.circle.fill" : "circle")
                    .rainbow(active: pickedCard === card, fallback: Color.white.opacity(0.4))
            }
            .padding(10)
            .background(Color.white.opacity(pickedCard === card ? 0.14 : 0.05))
            .cornerRadius(12)
            .rainbowRim(cornerRadius: 12, active: pickedCard === card, inactiveColor: Color.white.opacity(0.12))
        }
        .buttonStyle(.plain)
    }

    private func add() {
        guard let number = selectedNumber else { return }
        let fact = pickedCard?.fact ?? trimmedText
        guard !fact.isEmpty else { return }
        onAdd(PegSlot(
            number: number,
            pegWord: word,
            fact: fact,
            bindings: pickedCard?.scene ?? []
        ))
        dismiss()
    }
}

#Preview {
    PegSlotPicker(usedNumbers: []) { _ in }
        .demoModelContainer()
}
