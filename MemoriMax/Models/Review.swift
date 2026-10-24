import Foundation
import SwiftData

// MARK: - Unified review
//
// One active-recall item can come from a gallery binding, a palace station, or
// a peg slot. ReviewRecord stores only scheduling state, keyed by a stable
// string, so the three source models stay untouched.

enum ReviewSource: String, Codable, Hashable {
    case major
    case palace
    case peg

    var title: String {
        switch self {
        case .major: return "Major System"
        case .palace: return "Memory Palace"
        case .peg: return "Peg System"
        }
    }

    var icon: String {
        switch self {
        case .major: return "textformat.abc"
        case .palace: return "house"
        case .peg: return "list.number"
        }
    }
}

struct ReviewItem: Identifiable, Hashable {
    let id: String
    let prompt: String
    let answer: String
    let detail: String
    let imageFact: String?
    let source: ReviewSource
}

enum ReviewBuilder {
    static func items(cards: [GalleryCard], palaces: [MemoryPalace], pegLists: [PegList]) -> [ReviewItem] {
        var items: [ReviewItem] = []

        for card in cards {
            for binding in card.scene {
                items.append(ReviewItem(
                    id: "major|\(card.fact)|\(binding.digits)|\(binding.word)|\(card.createdAt.timeIntervalSince1970)",
                    prompt: binding.digits,
                    answer: binding.word,
                    detail: card.fact,
                    imageFact: card.fact,
                    source: .major
                ))
            }
        }

        for palace in palaces {
            for station in palace.stations {
                items.append(ReviewItem(
                    id: "palace|\(station.id.uuidString)",
                    prompt: station.location.isEmpty ? "This stop" : station.location,
                    answer: station.fact,
                    detail: station.bindings.map { "\($0.digits) · \($0.word)" }.joined(separator: "   "),
                    imageFact: station.fact,
                    source: .palace
                ))
            }
        }

        for list in pegLists {
            for slot in list.slots {
                items.append(ReviewItem(
                    id: "peg|\(slot.id.uuidString)",
                    prompt: "\(slot.number) · \(slot.pegWord)",
                    answer: slot.fact,
                    detail: slot.bindings.map { "\($0.digits) · \($0.word)" }.joined(separator: "   "),
                    imageFact: slot.fact,
                    source: .peg
                ))
            }
        }

        return items
    }

    /// Items with no record yet, or whose record is due. Shared by ReviewView
    /// and the due badges on the menu / Practice hub so they can never drift.
    static func dueItems(cards: [GalleryCard],
                         palaces: [MemoryPalace],
                         pegLists: [PegList],
                         records: [ReviewRecord],
                         now: Date = Date()) -> [ReviewItem] {
        let byKey = Dictionary(records.map { ($0.itemKey, $0) }, uniquingKeysWith: { first, _ in first })
        return items(cards: cards, palaces: palaces, pegLists: pegLists).filter { item in
            guard let record = byKey[item.id] else { return true }
            return record.dueAt <= now
        }
    }
}

/// Scheduling state for one review item. `Again` keeps it due, `Good` pushes
/// it three days out, `Easy` a week.
@Model
final class ReviewRecord {
    @Attribute(.unique) var itemKey: String
    var dueAt: Date
    var lastReviewedAt: Date?
    var streak: Int
    var lapses: Int

    init(itemKey: String, dueAt: Date = Date(), lastReviewedAt: Date? = nil,
         streak: Int = 0, lapses: Int = 0) {
        self.itemKey = itemKey
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.streak = streak
        self.lapses = lapses
    }
}
