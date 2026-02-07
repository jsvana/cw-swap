import Foundation
import Observation

@MainActor
@Observable
class ListingsViewModel {
    private let service = ListingsService()

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
    private let perPage = 20

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
            case .priceAsc: "Price: Low → High"
            case .priceDesc: "Price: High → Low"
            }
        }
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedSource != nil || !searchQuery.isEmpty
            || priceMin != nil || priceMax != nil || hasPhotoOnly
    }

    func loadListings() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        currentPage = 1

        do {
            let page = try await service.fetchListings(
                page: 1,
                perPage: perPage,
                source: selectedSource,
                category: selectedCategory,
                query: searchQuery.isEmpty ? nil : searchQuery,
                priceMin: priceMin,
                priceMax: priceMax,
                hasPhoto: hasPhotoOnly ? true : nil,
                sort: sortOption.rawValue
            )
            listings = page.listings
            hasMore = page.hasMore
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true

        let nextPage = currentPage + 1
        do {
            let page = try await service.fetchListings(
                page: nextPage,
                perPage: perPage,
                source: selectedSource,
                category: selectedCategory,
                query: searchQuery.isEmpty ? nil : searchQuery,
                priceMin: priceMin,
                priceMax: priceMax,
                hasPhoto: hasPhotoOnly ? true : nil,
                sort: sortOption.rawValue
            )
            listings.append(contentsOf: page.listings)
            hasMore = page.hasMore
            currentPage = nextPage
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func loadCategories() async {
        do {
            categories = try await service.fetchCategories()
        } catch {
            self.error = error
        }
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
