import Foundation
import SwiftData

// MARK: - Peg list
//
// A peg list is the Peg System's answer to a memory palace: an ordered set of
// fixed pegs (00 sauce, 01 suit, …) with one item hung on each peg. The peg
// word is fixed by the system; the item is a snapshot of a gallery scene (or a
// plain-text item), so art can be looked up live by fact just like palaces.

struct PegSlot: Codable, Hashable, Identifiable {
    var id: UUID
    /// Two-digit peg code, e.g. "43".
    var number: String
    /// The fixed peg word for `number`, e.g. "ram".
    var pegWord: String
    /// The thing hanging on the peg.
    var fact: String
    /// The scene's number↔word pairs, snapshotted from the source card.
    var bindings: [MnemonicBinding]

    init(id: UUID = UUID(), number: String, pegWord: String, fact: String,
         bindings: [MnemonicBinding] = []) {
        self.id = id
        self.number = number
        self.pegWord = pegWord
        self.fact = fact
        self.bindings = bindings
    }
}

@Model
final class PegList {
    var name: String
    var createdAt: Date
    var slots: [PegSlot] = []
    var lastWalkedAt: Date?

    init(name: String, slots: [PegSlot] = []) {
        self.name = name
        self.createdAt = Date()
        self.slots = slots
    }

    // MARK: - Slot editing
    //
    // Mutate a copy then reassign, same rule as MemoryPalace: SwiftData only
    // notices a change to the array property itself.

    func addSlot(_ slot: PegSlot) {
        var next = slots
        next.removeAll { $0.number == slot.number }
        next.append(slot)
        next.sort { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
        slots = next
    }

    func removeSlot(at index: Int) {
        var next = slots
        guard next.indices.contains(index) else { return }
        next.remove(at: index)
        slots = next
    }

    func setFact(_ text: String, at index: Int) {
        var next = slots
        guard next.indices.contains(index) else { return }
        next[index].fact = text
        slots = next
    }
}
