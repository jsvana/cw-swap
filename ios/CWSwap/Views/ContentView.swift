import SwiftUI

enum AppTab: String, Hashable {
    case browse, search, messages, saved, settings
}

struct ContentView: View {
    @State private var selectedTab = AppTab.browse

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
                    ConversationsPlaceholderView()
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
    }
}

struct ConversationsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Messages",
            systemImage: "message",
            description: Text("Log in to your QRZ account to message sellers.")
        )
        .navigationTitle("Messages")
    }
}
