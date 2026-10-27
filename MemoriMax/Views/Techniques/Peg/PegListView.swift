import SwiftUI
import SwiftData

// MARK: - Your peg lists
//
// The Peg System's home base: create a named list, then add fixed pegs and
// hang one item on each. Tapping a list opens the builder.

struct PegListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PegList.createdAt, order: .reverse) private var lists: [PegList]

    @State private var showNewSheet = false
    @State private var renameTarget: PegList?
    @State private var renameText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("PEG LISTS")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    if lists.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No peg lists yet.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Text("A peg list is a numbered set of fixed peg words. Hang one item on each peg, then walk the numbers to recall them in order.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().cardStyle()
                    } else {
                        ForEach(lists) { list in
                            listRow(list)
                        }
                    }

                    Button {
                        renameText = ""
                        showNewSheet = true
                    } label: {
                        Label("New peg list", systemImage: "plus")
                            .font(.subheadline.bold()).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(14)
                            .background(Color.white.opacity(0.08)).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: PegGeneratorView()) {
                        Text("Practice the 00–99 peg words →")
                            .font(.caption).foregroundColor(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Peg System")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showNewSheet) {
            PalaceNameSheet(
                title: "NEW PEG LIST",
                confirm: "Create",
                hint: "Name the list after what it holds: a shopping list, speech points, a deck of digits."
            ) { name in
                let list = PegList(name: name)
                modelContext.insert(list)
                try? modelContext.save()
            }
        }
        .alert("Rename peg list", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        ), presenting: renameTarget) { _ in
            TextField("Name", text: $renameText)
            Button("Save") {
                if let target = renameTarget {
                    let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { target.name = name; try? modelContext.save() }
                }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
    }

    private func listRow(_ list: PegList) -> some View {
        NavigationLink(destination: PegBuilderView(list: list)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "list.number")
                    .font(.title2).rainbow()
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08)).cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name).font(.headline).foregroundColor(.white)
                    Text(summary(list))
                        .font(.caption)
                        .foregroundColor(list.slots.isEmpty ? .white.opacity(0.6) : .green.opacity(0.9))
                }
                Spacer()
                Menu {
                    Button {
                        renameText = list.name
                        renameTarget = list
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(list)
                        try? modelContext.save()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3).foregroundColor(.white.opacity(0.9))
                        .padding(4).background(Circle().fill(Color.black.opacity(0.55)))
                }
            }
            .padding(12).cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(list.name), \(summary(list))")
    }

    private func summary(_ list: PegList) -> String {
        if list.slots.isEmpty { return "No pegs yet. Tap to build the list" }
        return "\(list.slots.count) peg\(list.slots.count == 1 ? "" : "s") · ready to walk"
    }
}

#Preview {
    NavigationStack { PegListView() }
        .demoModelContainer()
}
