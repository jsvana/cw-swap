import SwiftUI

struct CraigslistSettingsView: View {
    @State var store: CraigslistRegionStore
    @State private var showAddRegion = false
    @State private var newTermText = ""
    @State private var locationManager = LocationManager()
    @State private var selectedRegionName: String?

    var body: some View {
        List {
            regionsSection
            searchTermsSection
        }
        .navigationTitle("Craigslist")
        .sheet(isPresented: $showAddRegion) {
            AddRegionSheetView(store: store)
        }
    }

    // MARK: - Regions

    private var regionsSection: some View {
        Section {
            Button {
                Task {
                    selectedRegionName = nil
                    if let coordinate = await locationManager.requestSingleLocation() {
                        selectedRegionName = store.enableNearestRegion(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                    }
                }
            } label: {
                HStack {
                    Label("Use My Location", systemImage: "location")
                    if locationManager.isLocating {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(locationManager.isLocating)

            if let name = selectedRegionName {
                Text("Enabled \(name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(store.regions) { region in
                Toggle(region.name, isOn: Binding(
                    get: { region.isEnabled },
                    set: { _ in store.toggleRegion(region) }
                ))
            }
            .onDelete(perform: store.removeRegions)

            Button {
                showAddRegion = true
            } label: {
                Label("Add Region", systemImage: "plus.circle")
            }
        } header: {
            Text("Regions")
        } footer: {
            let enabled = store.enabledRegions.count
            Text("\(store.regions.count) regions, \(enabled) enabled")
        }
    }

    // MARK: - Search Terms

    private var searchTermsSection: some View {
        Section {
            ForEach(store.searchTerms) { term in
                Toggle(term.term, isOn: Binding(
                    get: { term.isEnabled },
                    set: { _ in store.toggleTerm(term) }
                ))
            }
            .onDelete(perform: store.removeTerms)

            HStack {
                TextField("Add search term...", text: $newTermText)
                    .autocorrectionDisabled()
                    .onSubmit { addCustomTerm() }

                Button("Add") {
                    addCustomTerm()
                }
                .disabled(newTermText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Search Terms")
        } footer: {
            let enabled = store.enabledSearchTerms.count
            Text("\(store.searchTerms.count) terms, \(enabled) enabled")
        }
    }

    // MARK: - Helpers

    private func addCustomTerm() {
        let text = newTermText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let id = text.lowercased().replacingOccurrences(of: " ", with: "-")
        let term = CraigslistSearchTerm(id: id, term: text, isEnabled: true)
        store.addTerm(term)
        newTermText = ""
    }
}

private struct AddRegionSheetView: View {
    var store: CraigslistRegionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.availableRegions) { (region: CraigslistRegion) in
                    Button {
                        var enabled = region
                        enabled.isEnabled = true
                        store.addRegion(enabled)
                    } label: {
                        HStack {
                            Text(region.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Add Region")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
