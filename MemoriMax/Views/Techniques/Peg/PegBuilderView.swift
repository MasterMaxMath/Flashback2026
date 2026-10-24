import SwiftUI
import SwiftData

// MARK: - Build a peg list: hang items on fixed pegs
//
// Pegs are fixed 00–99 words, so the order is numeric rather than draggable.
// Add an unused peg, edit the item on it, remove it, or walk the whole list.

struct PegBuilderView: View {
    @Bindable var list: PegList

    @Environment(\.modelContext) private var modelContext
    @State private var showPicker = false
    @State private var editIndex: Int?
    @State private var editText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR PEGS")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    walkButton

                    if list.slots.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No pegs yet.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Text("Pick a peg — 00 sauce, 01 suit, 43 ram — and hang one vivid item on it. Five to fifteen pegs is a good start.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().cardStyle()
                    } else {
                        ForEach(Array(list.slots.enumerated()), id: \.element.id) { index, slot in
                            slotRow(index: index, slot: slot)
                        }
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add a peg", systemImage: "plus")
                            .font(.subheadline.bold()).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(14)
                            .background(Color.white.opacity(0.08)).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPicker) {
            PegSlotPicker(usedNumbers: Set(list.slots.map(\.number))) { slot in
                list.addSlot(slot)
                save()
            }
        }
        .alert("Edit item", isPresented: Binding(
            get: { editIndex != nil },
            set: { if !$0 { editIndex = nil } }
        ), presenting: editIndex) { index in
            TextField("What hangs on this peg?", text: $editText)
            Button("Save") {
                let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { list.setFact(text, at: index); save() }
                editIndex = nil
            }
            Button("Cancel", role: .cancel) { editIndex = nil }
        } message: { _ in
            Text("The peg word stays fixed; this is the thing you want to remember.")
        }
    }

    private var walkButton: some View {
        NavigationLink(destination: PegWalkView(list: list)) {
            Label("Walk this peg list", systemImage: "list.number")
                .font(.headline)
                .foregroundColor(list.slots.isEmpty ? .white.opacity(0.4) : .black)
                .frame(maxWidth: .infinity).padding(14)
                .background(list.slots.isEmpty ? Color.white.opacity(0.1) : Color.white)
                .cornerRadius(14)
        }
        .disabled(list.slots.isEmpty)
    }

    private func slotRow(index: Int, slot: PegSlot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(slot.number)
                    .font(.caption.monospaced()).foregroundColor(.black)
                    .frame(width: 40, height: 28)
                    .background(Color.green).cornerRadius(8)

                Text(slot.pegWord)
                    .font(.headline).foregroundColor(.white)

                Spacer()

                Menu {
                    Button {
                        editText = slot.fact
                        editIndex = index
                    } label: { Label("Edit item", systemImage: "pencil") }
                    Divider()
                    Button(role: .destructive) {
                        list.removeSlot(at: index); save()
                    } label: { Label("Remove peg", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3).foregroundColor(.white.opacity(0.9))
                        .padding(4).background(Circle().fill(Color.black.opacity(0.55)))
                }
            }

            HStack(alignment: .top, spacing: 12) {
                thumbnail(from: artFor(slot.fact), size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        editText = slot.fact
                        editIndex = index
                    } label: {
                        HStack(spacing: 6) {
                            Text(slot.fact).font(.subheadline).foregroundColor(.white.opacity(0.9))
                                .lineLimit(3).multilineTextAlignment(.leading)
                            Image(systemName: "pencil")
                                .font(.caption2).foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(slot.bindings, id: \.self) { b in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(b.digits).font(.caption.monospaced()).foregroundColor(.green)
                            Text(b.word).font(.subheadline.bold()).foregroundColor(.white)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(12).cardStyle()
    }

    private func artFor(_ fact: String) -> Data? {
        let descriptor = FetchDescriptor<GalleryCard>(predicate: #Predicate { $0.fact == fact })
        return (try? modelContext.fetch(descriptor))?.first?.imageData
    }

    private func save() { try? modelContext.save() }
}

#Preview {
    NavigationStack {
        PegBuilderView(list: PegList(name: "Shopping"))
    }
    .demoModelContainer()
}
