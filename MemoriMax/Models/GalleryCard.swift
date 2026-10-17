import Foundation
import SwiftData

// MARK: - Persistent gallery card (one saved mnemonic scene)
//
// Stored in SwiftData so the gallery survives app restarts. Art bytes use
// external storage to keep the database file small. `tag` is the group the
// card belongs to; it defaults to "default" so every mnemonic lands
// somewhere and older cards migrate cleanly.

@Model
final class GalleryCard {
    var fact: String
    var digits: String
    var word: String
    var tie: String
    var tag: String = "default"
    var createdAt: Date
    @Attribute(.externalStorage) var imageData: Data?

    init(fact: String, digits: String, word: String, tie: String,
         tag: String = "default", imageData: Data? = nil) {
        self.fact = fact
        self.digits = digits
        self.word = word
        self.tie = tie
        self.tag = tag
        self.createdAt = Date()
        self.imageData = imageData
    }
}
