import Foundation
import Observation

@MainActor
@Observable
class ListingDetailViewModel {
    private let service = ListingsService()

    var listing: Listing
    var isLoading = false
    var error: Error?

    init(listing: Listing) {
        self.listing = listing
    }

    func refresh() async {
        isLoading = true
        do {
            listing = try await service.fetchListing(id: listing.id)
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
