import Foundation
import SwiftData
import SwiftUI

// MARK: - A mnemonic card is a *scene*, not a number
//
// The tutorial's mnemonic is one replayable image ("a razor chases a remote")
// that can encode several number↔word bindings at once — 404 (razor, the
// chaser) and 431 (remote, the chased). So a card carries a fact, one or more
// bindings, and a single illustration. Number↔word pairs are the atoms; the
// scene is the retrieval unit.

/// One number↔word pairing inside a scene, e.g. 404 → razor.
struct MnemonicBinding: Codable, Hashable {
    var digits: String
    var word: String
    var tie: String
}

/// The app always works with the latest schema version.
typealias GalleryCard = GallerySchemaV5.GalleryCard

/// Preview-only in-memory store containing every app model, so previews that
/// can reach the gallery (and the quizzes) never mix implicit stores.
extension View {
    func demoModelContainer() -> some View {
        modelContainer(for: [GalleryCard.self, SavedQuiz.self, MemoryPalace.self], inMemory: true)
    }
}

// MARK: - V1: single-number cards (fact + one digits/word/tie)

enum GallerySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [GalleryCard.self] }

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
}

// MARK: - V2: scene cards (fact + one-or-more bindings + one image)

enum GallerySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [GalleryCard.self] }

    @Model
    final class GalleryCard {
        var fact: String
        /// Optional so the store can migrate in place (a mandatory attribute
        /// has no value for pre-existing rows). Read via `scene`.
        var bindings: [MnemonicBinding]?
        var tag: String = "default"
        var createdAt: Date
        @Attribute(.externalStorage) var imageData: Data?

        init(fact: String, bindings: [MnemonicBinding], tag: String = "default",
             imageData: Data? = nil) {
            self.fact = fact
            self.bindings = bindings
            self.tag = tag
            self.createdAt = Date()
            self.imageData = imageData
        }

        /// The scene's number↔word bindings, never nil.
        var scene: [MnemonicBinding] { bindings ?? [] }
    }
}

// MARK: - V3: adds saved quizzes (GalleryCard itself is unchanged)

enum GallerySchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] { [GallerySchemaV2.GalleryCard.self, SavedQuiz.self] }
}

// MARK: - V4: adds memory palaces (GalleryCard and SavedQuiz unchanged)

enum GallerySchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [GallerySchemaV2.GalleryCard.self, SavedQuiz.self, MemoryPalace.self]
    }
}

// MARK: - V5: adds the technique that created each card
//
// Every pre-V5 card came from the Major System flow, so "major" is both the
// default and the migration backfill.

enum GallerySchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [GalleryCard.self, SavedQuiz.self, MemoryPalace.self]
    }

    @Model
    final class GalleryCard {
        var fact: String
        /// Optional so the store can migrate in place (a mandatory attribute
        /// has no value for pre-existing rows). Read via `scene`.
        var bindings: [MnemonicBinding]?
        var tag: String = "default"
        var createdAt: Date
        @Attribute(.externalStorage) var imageData: Data?
        /// `MemoryTechnique.rawValue` — which technique built this mnemonic.
        var technique: String = MemoryTechnique.major.rawValue

        init(fact: String, bindings: [MnemonicBinding], tag: String = "default",
             imageData: Data? = nil,
             technique: String = MemoryTechnique.major.rawValue) {
            self.fact = fact
            self.bindings = bindings
            self.tag = tag
            self.createdAt = Date()
            self.imageData = imageData
            self.technique = technique
        }

        /// The scene's number↔word bindings, never nil.
        var scene: [MnemonicBinding] { bindings ?? [] }

        /// Typed accessor with a Major System fallback for legacy rows.
        var techniqueKind: MemoryTechnique { MemoryTechnique.from(technique) }
    }
}

// MARK: - Migration
//
// V1 → V2 is custom (single-number cards → scenes). V2 → V3, V3 → V4 and
// V4 → V5 are additive (new entities / a defaulted attribute), handled by
// lightweight migrations.

enum GalleryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GallerySchemaV1.self, GallerySchemaV2.self, GallerySchemaV3.self,
         GallerySchemaV4.self, GallerySchemaV5.self]
    }
    static var stages: [MigrationStage] {
        [
            v1ToV2,
            .lightweight(fromVersion: GallerySchemaV2.self, toVersion: GallerySchemaV3.self),
            .lightweight(fromVersion: GallerySchemaV3.self, toVersion: GallerySchemaV4.self),
            .lightweight(fromVersion: GallerySchemaV4.self, toVersion: GallerySchemaV5.self)
        ]
    }

    /// Carries legacy bindings between the two migration phases.
    private final class LegacyBox {
        var byDate: [Date: MnemonicBinding] = [:]
    }
    private static let legacy = LegacyBox()

    static let v1ToV2 = MigrationStage.custom(
        fromVersion: GallerySchemaV1.self,
        toVersion: GallerySchemaV2.self,
        willMigrate: { context in
            let old = try context.fetch(FetchDescriptor<GallerySchemaV1.GalleryCard>())
            var map: [Date: MnemonicBinding] = [:]
            for c in old {
                map[c.createdAt] = MnemonicBinding(digits: c.digits, word: c.word, tie: c.tie)
            }
            legacy.byDate = map
        },
        didMigrate: { context in
            let new = try context.fetch(FetchDescriptor<GallerySchemaV2.GalleryCard>())
            for card in new where (card.bindings ?? []).isEmpty {
                if let b = legacy.byDate[card.createdAt] {
                    card.bindings = [b]
                }
            }
            try context.save()
        }
    )
}
