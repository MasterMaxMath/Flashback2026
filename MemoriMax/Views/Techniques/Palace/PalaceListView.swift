import SwiftUI
import SwiftData

// MARK: - Your memory palaces
//
// Lists every route the user has built. Tapping one opens the builder, where
// stops are added and ordered; a palace with at least one stop can be walked.

struct PalaceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryPalace.createdAt, order: .reverse) private var palaces: [MemoryPalace]

    @State private var showNewSheet = false
    @State private var renameTarget: MemoryPalace?
    @State private var renameText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("MEMORY PALACES")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    if palaces.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No palaces yet.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Text("A palace is a route you already know — home, your walk to school. Build one and leave a scene at each stop.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().cardStyle()
                    } else {
                        ForEach(palaces) { palace in
                            palaceRow(palace)
                        }
                    }

                    Button {
                        renameText = ""
                        showNewSheet = true
                    } label: {
                        Label("New palace", systemImage: "plus")
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
        .navigationTitle("Memory Palace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showNewSheet) {
            PalaceNameSheet(title: "NEW PALACE", confirm: "Create") { name in
                let palace = MemoryPalace(name: name)
                modelContext.insert(palace)
                try? modelContext.save()
            }
        }
        .alert("Rename palace", isPresented: Binding(
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

    private func palaceRow(_ palace: MemoryPalace) -> some View {
        NavigationLink(destination: PalaceBuilderView(palace: palace)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.title2).foregroundColor(.green)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08)).cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(palace.name).font(.headline).foregroundColor(.white)
                    Text(stationSummary(palace))
                        .font(.caption).foregroundColor(palace.stations.isEmpty ? .white.opacity(0.6) : .green.opacity(0.9))
                }
                Spacer()
                Menu {
                    Button {
                        renameText = palace.name
                        renameTarget = palace
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(palace)
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
        .accessibilityLabel("\(palace.name), \(stationSummary(palace))")
    }

    private func stationSummary(_ palace: MemoryPalace) -> String {
        if palace.stations.isEmpty { return "No stops yet — tap to build the route" }
        return "\(palace.stations.count) stop\(palace.stations.count == 1 ? "" : "s") · ready to walk"
    }
}

// MARK: - Name sheet (create / rename a palace)

struct PalaceNameSheet: View {
    let title: String
    let confirm: String
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))

                TextField("e.g. My house, Walk to school", text: $name)
                    .font(.body).foregroundColor(.white)
                    .focused($focused)
                    .padding().background(Color.white.opacity(0.1)).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
                    .submitLabel(.done)
                    .onSubmit(commit)

                Text("Use a route you already know by heart — the more familiar, the better.")
                    .font(.caption).foregroundColor(.white.opacity(0.6))

                Button(confirm, action: commit)
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(trimmed.isEmpty ? Color.gray : Color.white).cornerRadius(12)
                    .disabled(trimmed.isEmpty)

                Button("Cancel") { dismiss() }
                    .font(.subheadline.bold()).foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .onAppear { focused = true }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed)
        dismiss()
    }
}

#Preview {
    NavigationStack { PalaceListView() }
        .demoModelContainer()
}
