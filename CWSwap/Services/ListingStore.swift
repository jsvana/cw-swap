import Foundation
import SwiftData

@MainActor
class ListingStore {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    struct UpsertResult: Sendable {
        let inserted: Int
        let updated: Int
        let unchanged: Int
    }

    @discardableResult
    func upsertListings(_ listings: [Listing]) throws -> UpsertResult {
        var inserted = 0, updated = 0, unchanged = 0

        for listing in listings {
            let id = listing.id
            let descriptor = FetchDescriptor<PersistedListing>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                // Skip if content hasn't changed
                if existing.contentHash == listing.contentHash && !existing.contentHash.isEmpty {
                    unchanged += 1
                    continue
                }
                // Update existing
                let fresh = PersistedListing(from: listing)
                existing.title = fresh.title
                existing.listingDescription = fresh.listingDescription
                existing.descriptionHtml = fresh.descriptionHtml
                existing.status = fresh.status
                existing.callsign = fresh.callsign
                existing.priceAmount = fresh.priceAmount
                existing.priceCurrency = fresh.priceCurrency
                existing.priceIncludesShipping = fresh.priceIncludesShipping
                existing.priceObo = fresh.priceObo
                existing.photoUrlsData = fresh.photoUrlsData
                existing.dateModified = fresh.dateModified
                existing.replies = fresh.replies
                existing.views = fresh.views
                existing.contactEmail = fresh.contactEmail
                existing.contactPhone = fresh.contactPhone
                existing.contactMethodsData = fresh.contactMethodsData
                existing.contentHash = fresh.contentHash
                existing.dateScraped = Date()
                updated += 1
            } else {
                modelContext.insert(PersistedListing(from: listing))
                inserted += 1
            }
        }
        try modelContext.save()
        return UpsertResult(inserted: inserted, updated: updated, unchanged: unchanged)
    }

    func fetchCachedListings(
        source: ListingSource? = nil,
        query: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        hasPhoto: Bool? = nil,
        hideSold: Bool = true,
        hideSeen: Bool = false,
        sort: String? = nil
    ) throws -> [Listing] {
        var descriptor = FetchDescriptor<PersistedListing>(
            sortBy: [SortDescriptor(\.datePosted, order: .reverse)]
        )
        descriptor.fetchLimit = 100

        let results = try modelContext.fetch(descriptor)

        // Apply filters in-memory (SwiftData predicates have limited expressiveness)
        var filtered: [Listing]
        if hideSeen {
            let seenIds = seenListingIds()
            filtered = results.filter { seenIds.contains($0.id) == false }.map { $0.toListing() }
        } else {
            filtered = results.map { $0.toListing() }
        }

        if hideSold {
            filtered = filtered.filter { $0.status != .sold }
        }
        if let source {
            filtered = filtered.filter { $0.source == source }
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

    /// Delete non-bookmarked listings older than the given number of days.
    @discardableResult
    func evictOldListings(olderThanDays days: Int = 30) throws -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<PersistedListing>(
            predicate: #Predicate {
                $0.isBookmarked == false && $0.dateScraped < cutoff
            }
        )
        let stale = try modelContext.fetch(descriptor)
        let count = stale.count
        for listing in stale {
            modelContext.delete(listing)
        }
        if count > 0 {
            try modelContext.save()
        }
        return count
    }

    func markAsSeen(listingIds: Set<String>) throws {
        for id in listingIds {
            let descriptor = FetchDescriptor<PersistedListing>(
                predicate: #Predicate { $0.id == id }
            )
            if let listing = try modelContext.fetch(descriptor).first, listing.seenAt == nil {
                listing.seenAt = Date()
            }
        }
        try modelContext.save()
    }

    func seenListingIds() -> Set<String> {
        let descriptor = FetchDescriptor<PersistedListing>(
            predicate: #Predicate { $0.seenAt != nil }
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return Set(results.map(\.id))
    }

    func bookmarkedListings() throws -> [Listing] {
        let descriptor = FetchDescriptor<PersistedListing>(
            predicate: #Predicate { $0.isBookmarked == true },
            sortBy: [SortDescriptor(\.dateScraped, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toListing() }
    }
}
