import SwiftUI
import SwiftData

// MARK: - Walk picker
//
// Practice-side shortcuts into the existing palace / peg walkthroughs.

struct WalkPickerView: View {
    enum Kind { case palace, peg }

    let kind: Kind

    @Query(sort: \MemoryPalace.createdAt, order: .reverse) private var palaces: [MemoryPalace]
    @Query(sort: \PegList.createdAt, order: .reverse) private var pegLists: [PegList]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(kind == .palace ? "MEMORY PALACES" : "PEG LISTS")
                        .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)

                    if kind == .palace {
                        if palaces.isEmpty {
                            emptyCard("No palaces yet.", "Build one in Techniques, then walk it here.")
                            NavigationLink(destination: PalaceListView()) {
                                actionRow("Build a palace", icon: "house")
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(palaces) { palace in
                                NavigationLink(destination: PalaceWalkView(palace: palace)) {
                                    row(palace.name,
                                        subtitle: palace.stations.isEmpty
                                            ? "No stops yet"
                                            : "\(palace.stations.count) stop\(palace.stations.count == 1 ? "" : "s")",
                                        icon: "figure.walk")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        if pegLists.isEmpty {
                            emptyCard("No peg lists yet.", "Build one in Techniques, then drill it here.")
                            NavigationLink(destination: PegListView()) {
                                actionRow("Build a peg list", icon: "list.number")
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(pegLists) { list in
                                NavigationLink(destination: PegWalkView(list: list)) {
                                    row(list.name,
                                        subtitle: list.slots.isEmpty
                                            ? "No pegs yet"
                                            : "\(list.slots.count) peg\(list.slots.count == 1 ? "" : "s")",
                                        icon: "list.number")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(kind == .palace ? "Palace Walk" : "Peg Drill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func row(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body).foregroundColor(.green)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08)).cornerRadius(12)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.bold()).foregroundColor(.white.opacity(0.5))
        }
        .padding(12).cardStyle()
    }

    private func actionRow(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold()).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(14)
            .background(Color.white.opacity(0.08)).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))
    }

    private func emptyCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundColor(.white.opacity(0.9))
            Text(body).font(.caption).foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().cardStyle()
    }
}

#Preview {
    NavigationStack { WalkPickerView(kind: .palace) }
        .demoModelContainer()
}
