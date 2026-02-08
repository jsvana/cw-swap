import SwiftUI

struct BrowseView: View {
    @State private var viewModel = ListingsViewModel()
    @Environment(\.modelContext) private var modelContext
    private let authService = AuthenticationService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourceFilterSection
                syncProgressSection
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
                await viewModel.loadListings()
            }
        }
    }

    @ViewBuilder
    private var sourceFilterSection: some View {
        Picker("Source", selection: $viewModel.selectedSource) {
            Text("All").tag(nil as ListingSource?)
            ForEach(ListingSource.allCases, id: \.self) { source in
                Text(source.displayName).tag(source as ListingSource?)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: viewModel.selectedSource) {
            Task { await viewModel.loadListings() }
        }
    }

    @ViewBuilder
    private var syncProgressSection: some View {
        if viewModel.isSyncing {
            VStack(spacing: 4) {
                ProgressView(value: viewModel.syncProgress)
                    .tint(.blue)
                Text(viewModel.syncStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        } else if !viewModel.syncStatus.isEmpty {
            Text(viewModel.syncStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }

        ForEach(viewModel.sourceErrors, id: \.self) { errorMsg in
            Text(errorMsg)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var recentListingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Listings")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal)

            if let error = viewModel.error {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if viewModel.selectedSource == .craigslist
                && viewModel.craigslistRegionStore.enabledRegions.isEmpty
                && !viewModel.isLoading
            {
                ContentUnavailableView {
                    Label("No Regions Selected", systemImage: "map")
                } description: {
                    Text("Enable at least one Craigslist region to see listings.")
                } actions: {
                    NavigationLink {
                        CraigslistSettingsView(store: viewModel.craigslistRegionStore)
                    } label: {
                        Text("Select Regions")
                    }
                    .buttonStyle(.borderedProminent)
                }
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

