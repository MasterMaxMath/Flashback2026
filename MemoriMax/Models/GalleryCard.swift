import Foundation
import SwiftData

// MARK: - Persistent gallery card (one saved mnemonic scene)
//
// Stored in SwiftData so the gallery survives app restarts. Art bytes use
// external storage to keep the database file small.

@Model
final class GalleryCard {
    var fact: String
    var digits: String
    var word: String
    var tie: String
    var createdAt: Date
    @Attribute(.externalStorage) var imageData: Data?

    init(fact: String, digits: String, word: String, tie: String, imageData: Data? = nil) {
        self.fact = fact
        self.digits = digits
        self.word = word
        self.tie = tie
        self.createdAt = Date()
        self.imageData = imageData
    }
}
