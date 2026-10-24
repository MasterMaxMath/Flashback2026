import Foundation
import SwiftData

// MARK: - Memory Palace (Method of Loci)
//
// A palace is a familiar route with ORDERED stations (loci). Each station
// holds one mnemonic scene — the same "one replayable image" unit the gallery
// already stores (fact + number↔word bindings + art). The station snapshots
// the fact/bindings so a palace keeps working even if the source gallery card
// is edited or removed; art is looked up live from the gallery by fact (the
// same rule Quiz.swift uses), so it is never duplicated.

/// One stop on a route: a location name plus the scene placed there.
struct PalaceStation: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    /// Where on the route the scene sits, e.g. "front door", "kitchen table".
    var location: String
    /// Snapshot of the scene's fact.
    var fact: String
    /// Snapshot of the scene's number↔word pairs.
    var bindings: [MnemonicBinding]

    init(id: UUID = UUID(), location: String, fact: String, bindings: [MnemonicBinding]) {
        self.id = id
        self.location = location
        self.fact = fact
        self.bindings = bindings
    }
}

/// A named route the user builds and walks. Stations are stored in route
/// order; the walkthrough replays them first to last.
@Model
final class MemoryPalace {
    var name: String
    var createdAt: Date
    var stations: [PalaceStation] = []
    var lastWalkedAt: Date?

    init(name: String, stations: [PalaceStation] = []) {
        self.name = name
        self.createdAt = Date()
        self.stations = stations
    }

    // MARK: - Station editing
    //
    // Mutate a copy then reassign: SwiftData only notices a change to the
    // array property itself, not to an element reached through it.

    func addStation(from card: GalleryCard) {
        var next = stations
        next.append(PalaceStation(
            location: "Stop \(next.count + 1)",
            fact: card.fact,
            bindings: card.scene
        ))
        stations = next
    }

    func removeStation(at index: Int) {
        var next = stations
        guard next.indices.contains(index) else { return }
        next.remove(at: index)
        stations = next
    }

    func moveStation(from index: Int, by offset: Int) {
        var next = stations
        let target = index + offset
        guard next.indices.contains(index), next.indices.contains(target) else { return }
        next.swapAt(index, target)
        stations = next
    }

    func setLocation(_ text: String, at index: Int) {
        var next = stations
        guard next.indices.contains(index) else { return }
        next[index].location = text
        stations = next
    }
}
