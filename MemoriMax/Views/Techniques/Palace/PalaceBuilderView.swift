import SwiftUI
import SwiftData

// MARK: - Build a palace: add and order stops
//
// The route is an ordered list of stops. "Add a stop" opens the scene picker;
// each stop can be renamed (its location on the route) and reordered. A palace
// with at least one stop can be walked.

struct PalaceBuilderView: View {
    @Bindable var palace: MemoryPalace

    @Environment(\.modelContext) private var modelContext
    @State private var showPicker = false
    @State private var renameIndex: Int?
    @State private var renameText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR ROUTE")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    walkButton

                    if palace.stations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No stops yet.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Text("Walk your route in your head and add one stop at a time: front door, hallway, kitchen… Five to fifteen works best.")
                                .font(.caption).foregroundColor(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().cardStyle()
                    } else {
                        ForEach(Array(palace.stations.enumerated()), id: \.element.id) { index, station in
                            stationRow(index: index, station: station)
                        }
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add a stop", systemImage: "plus")
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
        .navigationTitle(palace.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPicker) {
            PalaceScenePicker { card in
                palace.addStation(from: card)
                try? modelContext.save()
            }
        }
        .alert("Rename stop", isPresented: Binding(
            get: { renameIndex != nil },
            set: { if !$0 { renameIndex = nil } }
        ), presenting: renameIndex) { index in
            TextField("Location name", text: $renameText)
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                palace.setLocation(name.isEmpty ? "Stop \(index + 1)" : name, at: index)
                save()
                renameIndex = nil
            }
            Button("Cancel", role: .cancel) { renameIndex = nil }
        } message: { _ in
            Text("Name this place on your route, e.g. “front door”.")
        }
    }

    private var walkButton: some View {
        NavigationLink(destination: PalaceWalkView(palace: palace)) {
            Label("Walk this palace", systemImage: "figure.walk")
                .font(.headline)
                .foregroundColor(palace.stations.isEmpty ? .white.opacity(0.4) : .black)
                .frame(maxWidth: .infinity).padding(14)
                .background(palace.stations.isEmpty ? Color.white.opacity(0.1) : Color.white)
                .cornerRadius(14)
        }
        .disabled(palace.stations.isEmpty)
    }

    // MARK: - One stop

    private func stationRow(index: Int, station: PalaceStation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.headline).foregroundColor(.black)
                    .frame(width: 30, height: 30)
                    .background(RainbowGradient()).cornerRadius(15)

                Button {
                    renameText = station.location
                    renameIndex = index
                } label: {
                    HStack(spacing: 6) {
                        Text(station.location.isEmpty ? "Name this stop" : station.location)
                            .font(.headline)
                            .foregroundColor(station.location.isEmpty ? .white.opacity(0.5) : .white)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.caption).foregroundColor(.white.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rename stop \(index + 1)")

                Menu {
                    Button {
                        renameText = station.location
                        renameIndex = index
                    } label: { Label("Rename stop", systemImage: "pencil") }
                    Button {
                        palace.moveStation(from: index, by: -1); save()
                    } label: { Label("Move up", systemImage: "arrow.up") }
                        .disabled(index == 0)
                    Button {
                        palace.moveStation(from: index, by: 1); save()
                    } label: { Label("Move down", systemImage: "arrow.down") }
                        .disabled(index == palace.stations.count - 1)
                    Divider()
                    Button(role: .destructive) {
                        palace.removeStation(at: index); save()
                    } label: { Label("Remove stop", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3).foregroundColor(.white.opacity(0.9))
                        .padding(4).background(Circle().fill(Color.black.opacity(0.55)))
                }
            }

            HStack(alignment: .top, spacing: 12) {
                thumbnail(from: artFor(station.fact), size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.fact).font(.subheadline).foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                    ForEach(station.bindings, id: \.self) { b in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(b.digits).font(.caption.monospaced()).rainbow()
                            Text(b.word).font(.subheadline.bold()).foregroundColor(.white)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(12).cardStyle()
    }

    // MARK: - Helpers

    /// Live art lookup by fact (the same rule the quiz uses) — the source card
    /// may have been edited or removed since the station was created.
    private func artFor(_ fact: String) -> Data? {
        let descriptor = FetchDescriptor<GalleryCard>(predicate: #Predicate { $0.fact == fact })
        return (try? modelContext.fetch(descriptor))?.first?.imageData
    }

    private func save() { try? modelContext.save() }
}

#Preview {
    NavigationStack {
        PalaceBuilderView(palace: MemoryPalace(name: "My house"))
    }
    .demoModelContainer()
}
