import SwiftUI
import SwiftData

@main
struct MemoriMaxApp: App {
    private let container: ModelContainer
    @StateObject private var saveTags = SaveTagPresenter()

    init() {
        let schema = Schema(versionedSchema: GallerySchemaV7.self)
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: GalleryMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
            // Seed once, synchronously, before any view fetches from the store.
            // Idempotent — only adds demo cards whose facts are missing — so a
            // plain relaunch adds nothing. `GalleryView` also seeds defensively
            // when it appears, and the Restore button seeds on demand.
            GalleryView.seedIfNeeded(context: container.mainContext)
            self.container = container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Home()
            }
            .environmentObject(saveTags)
            .sheet(item: $saveTags.request) { request in
                SaveTagSheet(
                    word: request.word,
                    fact: request.fact,
                    existingTags: request.existingTags,
                    onSave: request.onSave,
                    header: request.header,
                    confirmLabel: request.confirmLabel
                )
            }
        }
        .modelContainer(container)
    }
}
