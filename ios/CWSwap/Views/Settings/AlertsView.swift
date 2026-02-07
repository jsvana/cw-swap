import SwiftUI

struct AlertsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AlertsViewModel()
    @State private var showingAddSheet = false
    @State private var editingAlert: TriggerAlert?

    var body: some View {
        List {
            if !viewModel.notificationsAuthorized {
                Section {
                    Button {
                        Task { await viewModel.requestNotificationPermission() }
                    } label: {
                        Label(
                            "Enable Notifications",
                            systemImage: "bell.badge"
                        )
                    }
                } footer: {
                    Text("Notifications must be enabled to receive alerts when new matching listings appear.")
                }
            }

            if viewModel.alerts.isEmpty {
                ContentUnavailableView(
                    "No Alerts",
                    systemImage: "bell.slash",
                    description: Text("Add an alert to get notified when listings matching your criteria are posted.")
                )
            } else {
                Section {
                    ForEach(viewModel.alerts, id: \.id) { alert in
                        AlertRowView(
                            alert: alert,
                            onToggle: { viewModel.toggleAlert(alert) },
                            onEdit: { editingAlert = alert }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteAlert(viewModel.alerts[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Alerts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                AlertFormView { name, keyword, category, source, priceMin, priceMax in
                    viewModel.addAlert(
                        name: name,
                        keyword: keyword,
                        category: category,
                        source: source,
                        priceMin: priceMin,
                        priceMax: priceMax
                    )
                }
            }
        }
        .sheet(item: $editingAlert) { alert in
            NavigationStack {
                AlertFormView(
                    existingAlert: alert
                ) { name, keyword, category, source, priceMin, priceMax in
                    viewModel.updateAlert(
                        alert,
                        name: name,
                        keyword: keyword,
                        category: category,
                        source: source,
                        priceMin: priceMin,
                        priceMax: priceMax
                    )
                }
            }
        }
        .task {
            viewModel.setModelContext(modelContext)
            await viewModel.load()
        }
    }
}

private struct AlertRowView: View {
    let alert: TriggerAlert
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.name)
                        .font(.headline)
                        .foregroundStyle(alert.isEnabled ? .primary : .secondary)
                    Text(alert.displaySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastTriggered = alert.lastTriggered {
                        Text("Last triggered \(lastTriggered, format: .relative(presentation: .named))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { alert.isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }
        }
        .buttonStyle(.plain)
    }
}
