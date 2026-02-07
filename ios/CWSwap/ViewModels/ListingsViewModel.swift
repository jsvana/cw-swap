import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class ListingsViewModel {
    private let scrapingService = ScrapingService()
    private var listingStore: ListingStore?

    var listings: [Listing] = []
    var categories: [CategoryInfo] = []
    var isLoading = false
    var error: Error?
    var hasMore = true

    // Filters
    var selectedCategory: ListingCategory?
    var selectedSource: ListingSource?
    var searchQuery = ""
    var sortOption: SortOption = .newest
    var priceMin: Double?
    var priceMax: Double?
    var hasPhotoOnly = false

    private var currentPage = 1

    enum SortOption: String, CaseIterable, Identifiable, Sendable {
        case newest
        case oldest
        case priceAsc = "price_asc"
        case priceDesc = "price_desc"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .newest: "Newest"
            case .oldest: "Oldest"
            case .priceAsc: "Price: Low \u{2192} High"
            case .priceDesc: "Price: High \u{2192} Low"
            }
        }
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedSource != nil || !searchQuery.isEmpty
            || priceMin != nil || priceMax != nil || hasPhotoOnly
    }

    func setModelContext(_ context: ModelContext) {
        self.listingStore = ListingStore(modelContext: context)
    }

    func loadListings() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        currentPage = 1

        // Show cached data immediately
        if let store = listingStore {
            do {
                let cached = try store.fetchCachedListings(
                    source: selectedSource,
                    category: selectedCategory,
                    query: searchQuery.isEmpty ? nil : searchQuery,
                    priceMin: priceMin,
                    priceMax: priceMax,
                    hasPhoto: hasPhotoOnly ? true : nil,
                    sort: sortOption.rawValue
                )
                if !cached.isEmpty {
                    listings = cached
                }
            } catch {
                // Cache miss is fine, will scrape
            }
        }

        // Scrape fresh data in background
        do {
            let fresh = try await scrapingService.fetchListings(
                page: 1,
                source: selectedSource,
                category: selectedCategory,
                query: searchQuery.isEmpty ? nil : searchQuery,
                priceMin: priceMin,
                priceMax: priceMax,
                hasPhoto: hasPhotoOnly ? true : nil,
                sort: sortOption.rawValue
            )
            listings = fresh
            hasMore = !fresh.isEmpty

            // Persist to SwiftData
            if let store = listingStore {
                try? store.upsertListings(fresh)
            }
        } catch {
            // Only show error if we have no cached data
            if listings.isEmpty {
                self.error = error
            }
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true

        let nextPage = currentPage + 1
        do {
            let fresh = try await scrapingService.fetchListings(
                page: nextPage,
                source: selectedSource,
                category: selectedCategory,
                query: searchQuery.isEmpty ? nil : searchQuery,
                priceMin: priceMin,
                priceMax: priceMax,
                hasPhoto: hasPhotoOnly ? true : nil,
                sort: sortOption.rawValue
            )
            listings.append(contentsOf: fresh)
            hasMore = !fresh.isEmpty
            currentPage = nextPage

            if let store = listingStore {
                try? store.upsertListings(fresh)
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func loadCategories() {
        categories = scrapingService.fetchCategories()
    }

    func clearFilters() {
        selectedCategory = nil
        selectedSource = nil
        searchQuery = ""
        sortOption = .newest
        priceMin = nil
        priceMax = nil
        hasPhotoOnly = false
    }
}
