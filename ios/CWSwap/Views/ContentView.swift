import SwiftUI

enum AppTab: String, Hashable {
    case browse, search, messages, saved, settings
}

struct ContentView: View {
    @State private var selectedTab = AppTab.browse
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Browse", systemImage: "antenna.radiowaves.left.and.right", value: AppTab.browse) {
                NavigationStack {
                    BrowseView()
                }
            }

            SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                NavigationStack {
                    SearchView()
                }
            }

            SwiftUI.Tab("Messages", systemImage: "message", value: AppTab.messages) {
                NavigationStack {
                    ConversationsView()
                }
            }

            SwiftUI.Tab("Saved", systemImage: "bookmark", value: AppTab.saved) {
                NavigationStack {
                    SavedView()
                }
            }

            SwiftUI.Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(.accentColor)
        .task {
            let store = ListingStore(modelContext: modelContext)
            _ = try? store.evictOldListings()
        }
    }
}
