import SwiftUI

struct BrowseView: View {
    @State private var viewModel = ListingsViewModel()
    @Environment(\.modelContext) private var modelContext
    private let authService = AuthenticationService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                categorySection
                recentListingsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("CW Swap")
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listing: listing)
        }
        .refreshable {
            await viewModel.loadListings()
        }
        .task {
            viewModel.setModelContext(modelContext)
            if viewModel.listings.isEmpty {
                viewModel.loadCategories()
                await viewModel.loadListings()
            }
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.categories) { info in
                        CategoryChip(info: info) {
                            viewModel.selectedCategory = info.category
                            Task { await viewModel.loadListings() }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var recentListingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Listings")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal)

            if let error = viewModel.error {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if viewModel.listings.isEmpty && !viewModel.isLoading && !authService.isLoggedIn {
                ContentUnavailableView {
                    Label("Log In to Browse", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Sign in to your QRZ account to browse ham radio listings.")
                } actions: {
                    NavigationLink {
                        QRZLoginView()
                    } label: {
                        Text("QRZ Account Settings")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.listings.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Listings",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("No listings found. Pull to refresh.")
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.listings) { listing in
                        NavigationLink(value: listing) {
                            ListingCardView(listing: listing)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if listing.id == viewModel.listings.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }

                    if viewModel.isLoading && !viewModel.listings.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct CategoryChip: View {
    let info: CategoryInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: info.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(info.displayName)
                    .font(.caption)
                    .lineLimit(1)

                Text("\(info.listingCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }
}
