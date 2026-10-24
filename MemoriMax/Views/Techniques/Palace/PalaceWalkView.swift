import SwiftUI
import SwiftData
import UIKit

// MARK: - Walk the palace
//
// Replays the route stop by stop in order. Each page shows the location and
// the scene art; the fact and numbers stay hidden until the walker tries to
// recall them (active recall, not recognition).

struct PalaceWalkView: View {
    let palace: MemoryPalace

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GalleryCard.createdAt, order: .reverse) private var cards: [GalleryCard]

    @State private var index = 0
    @State private var revealed: Set<UUID> = []

    private var stations: [PalaceStation] { palace.stations }

    /// fact → art, looked up live so a walk reflects the current gallery.
    private var artByFact: [String: Data] {
        var map: [String: Data] = [:]
        for card in cards where card.imageData != nil {
            if map[card.fact] == nil { map[card.fact] = card.imageData }
        }
        return map
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("HomeBackground").resizable().scaledToFill().ignoresSafeArea().opacity(0.9)

            if stations.isEmpty {
                VStack(spacing: 12) {
                    Text("This palace has no stops yet.")
                        .font(.headline).foregroundColor(.white)
                    Text("Go back and add at least one stop to walk it.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.7))
                }
                .padding().cardStyle().padding(20)
            } else {
                VStack(spacing: 0) {
                    progressHeader

                    TabView(selection: $index) {
                        ForEach(Array(stations.enumerated()), id: \.element.id) { i, station in
                            stationPage(station).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    bottomNav
                }
            }
        }
        .navigationTitle(palace.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            palace.lastWalkedAt = Date()
            try? modelContext.save()
        }
    }

    // MARK: - Progress

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("STOP \(index + 1) OF \(stations.count)")
                .font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: Double(index + 1), total: Double(stations.count))
                .tint(.white).opacity(0.9)
        }
        .padding(.horizontal, 32).padding(.top, 10)
    }

    // MARK: - One stop

    private func stationPage(_ station: PalaceStation) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text(station.location.isEmpty ? "Stop" : station.location)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white).multilineTextAlignment(.center)
                    .padding(.top, 16)

                artView(for: station)

                if revealed.contains(station.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(station.fact)
                            .font(.headline).foregroundColor(.white).lineSpacing(3)
                        ForEach(station.bindings, id: \.self) { b in
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(b.digits).font(.caption.monospaced()).rainbow()
                                    Text(b.word).font(.headline).foregroundColor(.white)
                                }
                                if !b.tie.isEmpty {
                                    Text(b.tie).font(.caption).foregroundColor(.white.opacity(0.65))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16).cardStyle()
                } else {
                    Text("What lives here? Picture it, then reveal.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Button {
                    Haptics.reveal()
                    if revealed.contains(station.id) { revealed.remove(station.id) }
                    else { revealed.insert(station.id) }
                } label: {
                    Text(revealed.contains(station.id) ? "Hide" : "Reveal")
                        .font(.subheadline.bold()).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(14)
                        .background(Color.white).cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func artView(for station: PalaceStation) -> some View {
        if let data = artByFact[station.fact], let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable().scaledToFit()
                .frame(maxHeight: 240).frame(maxWidth: .infinity)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15)))
        } else {
            PlaceholderImageView(
                label: "SCENE ART: \(station.bindings.first?.word.lowercased() ?? station.fact)",
                icon: "photo"
            )
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack {
            Button("Back") {
                guard index > 0 else { return }
                Haptics.tap()
                withAnimation { index -= 1 }
            }
            .disabled(index == 0).foregroundColor(index == 0 ? .gray : .white)
            Spacer()
            HStack(spacing: 5) {
                ForEach(stations.indices, id: \.self) { i in
                    Circle().fill(i == index ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if index < stations.count - 1 {
                Button("Next") {
                    Haptics.tap()
                    withAnimation { index += 1 }
                }
                .foregroundColor(.white).bold()
            } else {
                Button("Done") { dismiss() }
                    .foregroundColor(.black).bold()
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.white).cornerRadius(20)
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        PalaceWalkView(palace: MemoryPalace(name: "My house"))
    }
    .demoModelContainer()
}
