import SwiftUI
import SwiftData

@main
struct MemoriMaxApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Home()
            }
        }
        .modelContainer(for: GalleryCard.self)
    }
}
