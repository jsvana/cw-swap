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
                    SavedPlaceholderView()
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

struct SavedPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Saved",
            systemImage: "bookmark",
            description: Text("Bookmarked listings and saved searches will appear here.")
        )
        .navigationTitle("Saved")
    }
}

struct SettingsView: View {
    @AppStorage(APIClient.serverURLKey) private var serverURL = APIClient.defaultServerURL

    var body: some View {
        Form {
            Section("Server") {
                TextField("Server URL", text: $serverURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                if serverURL != APIClient.defaultServerURL {
                    Button("Reset to Default") {
                        serverURL = APIClient.defaultServerURL
                    }
                }
            }

            Section("Account") {
                Label("Log in to QRZ", systemImage: "person.circle")
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Source", value: "QRZ Swapmeet, QTH.com")
            }
        }
        .navigationTitle("Settings")
    }
}
