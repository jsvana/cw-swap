import SwiftUI
import SwiftData

@main
struct CWSwapApp: App {
    init() {
        // Limit image cache: 25 MB memory, 100 MB disk
        URLCache.shared = URLCache(
            memoryCapacity: 25 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PersistedListing.self])
    }
}
