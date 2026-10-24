import Foundation

// MARK: - Memory technique
//
// The technique used to build a mnemonic. Stored on each gallery card as a
// stable raw string so the gallery can group cards by technique, and so new
// techniques can be added without touching existing data.

enum MemoryTechnique: String, CaseIterable, Identifiable {
    case major = "major"
    case peg = "peg"
    case palace = "palace"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .major: return "Major System"
        case .peg: return "Peg System"
        case .palace: return "Memory Palace"
        }
    }

    var icon: String {
        switch self {
        case .major: return "textformat.abc"
        case .peg: return "list.number"
        case .palace: return "house"
        }
    }

    /// Unknown/legacy raw values fall back to the Major System, which is what
    /// every card predating the `technique` field was created with.
    static func from(_ raw: String) -> MemoryTechnique {
        MemoryTechnique(rawValue: raw) ?? .major
    }
}
