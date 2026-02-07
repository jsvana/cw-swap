import SwiftUI
import SwiftData

@main
struct CWSwapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PersistedListing.self])
    }
}
