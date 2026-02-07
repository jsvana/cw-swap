import SwiftUI

struct SearchView: View {
    @State private var viewModel = ListingsViewModel()
    @State private var showingFilters = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            if viewModel.hasActiveFilters {
                activeFiltersSection
            }

            if let error = viewModel.error {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if viewModel.listings.isEmpty && !viewModel.isLoading && !viewModel.searchQuery.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchQuery)
            } else {
                ForEach(viewModel.listings) { listing in
                    NavigationLink(value: listing) {
                        ListingCardView(listing: listing)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.hidden)
                    .onAppear {
                        if listing.id == viewModel.listings.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search")
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listing: listing)
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search radios, callsigns...")
        .onSubmit(of: .search) {
            Task { await viewModel.loadListings() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingFilters = true
                } label: {
                    Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheetView(viewModel: viewModel) {
                Task { await viewModel.loadListings() }
            }
        }
        .task {
            viewModel.setModelContext(modelContext)
        }
    }

    @ViewBuilder
    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let category = viewModel.selectedCategory {
                    FilterChip(label: category.displayName) {
                        viewModel.selectedCategory = nil
                        Task { await viewModel.loadListings() }
                    }
                }

                if let source = viewModel.selectedSource {
                    FilterChip(label: source.displayName) {
                        viewModel.selectedSource = nil
                        Task { await viewModel.loadListings() }
                    }
                }

                if viewModel.hasPhotoOnly {
                    FilterChip(label: "Has Photo") {
                        viewModel.hasPhotoOnly = false
                        Task { await viewModel.loadListings() }
                    }
                }

                if viewModel.priceMin != nil || viewModel.priceMax != nil {
                    let label = formatPriceRange(min: viewModel.priceMin, max: viewModel.priceMax)
                    FilterChip(label: label) {
                        viewModel.priceMin = nil
                        viewModel.priceMax = nil
                        Task { await viewModel.loadListings() }
                    }
                }

                Button("Clear All") {
                    viewModel.clearFilters()
                    Task { await viewModel.loadListings() }
                }
                .font(.caption)
            }
            .padding(.horizontal)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private func formatPriceRange(min: Double?, max: Double?) -> String {
        switch (min, max) {
        case (.some(let lo), .some(let hi)):
            "$\(Int(lo))–$\(Int(hi))"
        case (.some(let lo), nil):
            "$\(Int(lo))+"
        case (nil, .some(let hi)):
            "Up to $\(Int(hi))"
        default:
            "Price"
        }
    }
}

struct FilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.2))
        .foregroundStyle(Color.blue)
        .clipShape(Capsule())
    }
}
