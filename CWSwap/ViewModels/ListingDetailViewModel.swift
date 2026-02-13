import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class ListingDetailViewModel {
    private let scrapingService = ScrapingService()
    private var listingStore: ListingStore?

    var listing: Listing
    var isLoading = false
    var error: Error?
    var isBookmarked = false

    init(listing: Listing) {
        self.listing = listing
    }

    func setModelContext(_ context: ModelContext) {
        self.listingStore = ListingStore(modelContext: context)
        self.isBookmarked = (try? listingStore?.isBookmarked(listingId: listing.id)) ?? false
    }

    func refresh() async {
        isLoading = true
        // Re-scrape the listing from its source URL
        // For now, this is a no-op since we'd need to parse the source URL
        // to determine which scraper to use
        isLoading = false
    }

    func toggleBookmark() {
        guard let store = listingStore else { return }
        do {
            // Ensure the listing is persisted first
            try store.upsertListings([listing])
            try store.toggleBookmark(listingId: listing.id)
            isBookmarked.toggle()
        } catch {
            self.error = error
        }
    }
}
