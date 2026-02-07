import Foundation
import SwiftData

@MainActor
class ListingStore {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func upsertListings(_ listings: [Listing]) throws {
        for listing in listings {
            let id = listing.id
            let descriptor = FetchDescriptor<PersistedListing>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                // Update existing
                let updated = PersistedListing(from: listing)
                existing.title = updated.title
                existing.listingDescription = updated.listingDescription
                existing.descriptionHtml = updated.descriptionHtml
                existing.status = updated.status
                existing.callsign = updated.callsign
                existing.priceAmount = updated.priceAmount
                existing.priceCurrency = updated.priceCurrency
                existing.priceIncludesShipping = updated.priceIncludesShipping
                existing.priceObo = updated.priceObo
                existing.photoUrlsData = updated.photoUrlsData
                existing.dateModified = updated.dateModified
                existing.replies = updated.replies
                existing.views = updated.views
                existing.contactEmail = updated.contactEmail
                existing.contactPhone = updated.contactPhone
                existing.contactMethodsData = updated.contactMethodsData
                existing.dateScraped = Date()
            } else {
                modelContext.insert(PersistedListing(from: listing))
            }
        }
        try modelContext.save()
    }

    func fetchCachedListings(
        source: ListingSource? = nil,
        category: ListingCategory? = nil,
        query: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        hasPhoto: Bool? = nil,
        hideSold: Bool = true,
        sort: String? = nil
    ) throws -> [Listing] {
        var descriptor = FetchDescriptor<PersistedListing>(
            sortBy: [SortDescriptor(\.datePosted, order: .reverse)]
        )
        descriptor.fetchLimit = 100

        let results = try modelContext.fetch(descriptor)

        // Apply filters in-memory (SwiftData predicates have limited expressiveness)
        var filtered = results.map { $0.toListing() }

        if hideSold {
            filtered = filtered.filter { $0.status != .sold }
        }
        if let source {
            filtered = filtered.filter { $0.source == source }
        }
        if let category {
            filtered = filtered.filter { $0.category == category }
        }
        if let query, !query.isEmpty {
            let lowered = query.lowercased()
            filtered = filtered.filter {
                $0.title.lowercased().contains(lowered)
                || $0.description.lowercased().contains(lowered)
                || $0.callsign.lowercased().contains(lowered)
            }
        }
        if let priceMin {
            filtered = filtered.filter { ($0.price?.amount ?? 0) >= priceMin }
        }
        if let priceMax {
            filtered = filtered.filter { ($0.price?.amount ?? Double.infinity) <= priceMax }
        }
        if hasPhoto == true {
            filtered = filtered.filter { $0.hasPhotos }
        }

        switch sort {
        case "oldest":
            filtered.sort { $0.datePosted < $1.datePosted }
        case "price_asc":
            filtered.sort { ($0.price?.amount ?? 0) < ($1.price?.amount ?? 0) }
        case "price_desc":
            filtered.sort { ($0.price?.amount ?? 0) > ($1.price?.amount ?? 0) }
        default:
            break // already sorted newest first
        }

        return filtered
    }

    func toggleBookmark(listingId: String) throws {
        let descriptor = FetchDescriptor<PersistedListing>(
            predicate: #Predicate { $0.id == listingId }
        )
        if let listing = try modelContext.fetch(descriptor).first {
            listing.isBookmarked.toggle()
            try modelContext.save()
        }
    }

    func isBookmarked(listingId: String) throws -> Bool {
        let descriptor = FetchDescriptor<PersistedListing>(
            predicate: #Predicate { $0.id == listingId }
        )
        return try modelContext.fetch(descriptor).first?.isBookmarked ?? false
    }

    func bookmarkedListings() throws -> [Listing] {
        let descriptor = FetchDescriptor<PersistedListing>(
            predicate: #Predicate { $0.isBookmarked == true },
            sortBy: [SortDescriptor(\.dateScraped, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toListing() }
    }
}
