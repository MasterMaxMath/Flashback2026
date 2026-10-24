import SwiftUI
import SwiftData

@main
struct MemoriMaxApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema(versionedSchema: GallerySchemaV5.self)
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
        }
        .modelContainer(container)
    }
}
