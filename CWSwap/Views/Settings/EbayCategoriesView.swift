import SwiftUI

struct EbayCategoriesView: View {
    @State var store: EbayCategoryStore
    @State private var searchQuery = ""
    @State private var searchResults: [EbaySearchCategory] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        List {
            categoriesSection
            searchSection
        }
        .navigationTitle("eBay Categories")
    }

    private var categoriesSection: some View {
        Section {
            ForEach(store.categories) { category in
                categoryRow(category)
            }
            .onDelete(perform: store.remove)
        } header: {
            Text("Categories")
        } footer: {
            let enabled = store.categories.filter(\.isEnabled).count
            Text("\(store.categories.count) categories, \(enabled) enabled")
        }
    }

    private func categoryRow(_ category: EbaySearchCategory) -> some View {
        Toggle(category.name, isOn: Binding(
            get: { category.isEnabled },
            set: { _ in store.toggle(category) }
        ))
    }

    private var searchSection: some View {
        Section("Search eBay Categories") {
            searchBar
            errorMessage
            searchResultsList
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack {
            TextField("Search categories...", text: $searchQuery)
                .autocorrectionDisabled()
                .onSubmit { Task { await search() } }

            if isSearching {
                ProgressView()
            } else {
                Button("Search") {
                    Task { await search() }
                }
                .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let error = searchError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var searchResultsList: some View {
        ForEach(searchResults) { result in
            searchResultRow(result)
        }
    }

    private func searchResultRow(_ result: EbaySearchCategory) -> some View {
        let alreadyAdded = store.categories.contains(where: { $0.id == result.id })
        return Button {
            store.add(result)
            searchResults.removeAll { $0.id == result.id }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(result.name)
                        .foregroundStyle(.primary)
                    Text("ID: \(result.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: alreadyAdded ? "checkmark" : "plus.circle")
                    .foregroundStyle(alreadyAdded ? .green : .accentColor)
            }
        }
        .disabled(alreadyAdded)
    }

    private func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        searchError = nil
        do {
            searchResults = try await store.searchCategories(query: query)
        } catch {
            searchError = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }
        isSearching = false
    }
}
