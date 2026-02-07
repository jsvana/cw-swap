import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Account") {
                NavigationLink {
                    QRZLoginView()
                } label: {
                    Label("QRZ Account", systemImage: "person.circle")
                }
            }

            Section("Notifications") {
                NavigationLink {
                    AlertsView()
                } label: {
                    Label("Alerts", systemImage: "bell.badge")
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Sources", value: "QRZ Swapmeet, QTH.com")
            }
        }
        .navigationTitle("Settings")
    }
}
