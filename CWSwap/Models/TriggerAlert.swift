import Foundation
import SwiftData

@Model
final class TriggerAlert {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var keyword: String = ""
    var category: String?
    var source: String?
    var priceMin: Double?
    var priceMax: Double?
    var isEnabled: Bool = true
    var dateCreated: Date = Date()
    var lastTriggered: Date?
    /// IDs of listings already notified, to avoid duplicate alerts.
    var notifiedListingIdsData: Data = Data()

    init() {}

    init(
        name: String,
        keyword: String = "",
        category: ListingCategory? = nil,
        source: ListingSource? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil
    ) {
        self.name = name
        self.keyword = keyword
        self.category = category?.rawValue
        self.source = source?.rawValue
        self.priceMin = priceMin
        self.priceMax = priceMax
    }

    var listingCategory: ListingCategory? {
        get { category.flatMap { ListingCategory(rawValue: $0) } }
        set { category = newValue?.rawValue }
    }

    var listingSource: ListingSource? {
        get { source.flatMap { ListingSource(rawValue: $0) } }
        set { source = newValue?.rawValue }
    }

    var notifiedListingIds: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: notifiedListingIdsData)) ?? []
        }
        set {
            notifiedListingIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Returns true if the given listing matches this trigger's criteria.
    func matches(_ listing: Listing) -> Bool {
        // Must be active for-sale listing
        guard listing.status == .forSale || listing.status == .forSaleOrTrade else {
            return false
        }

        // Keyword filter
        if !keyword.isEmpty {
            let lowered = keyword.lowercased()
            let matchesKeyword = listing.title.lowercased().contains(lowered)
                || listing.description.lowercased().contains(lowered)
                || listing.callsign.lowercased().contains(lowered)
            if !matchesKeyword { return false }
        }

        // Category filter
        if let listingCategory, listing.category != listingCategory {
            return false
        }

        // Source filter
        if let listingSource, listing.source != listingSource {
            return false
        }

        // Price range
        if let priceMin {
            guard let price = listing.price, price.amount >= priceMin else { return false }
        }
        if let priceMax {
            guard let price = listing.price, price.amount <= priceMax else { return false }
        }

        return true
    }

    var displaySummary: String {
        var parts: [String] = []
        if !keyword.isEmpty { parts.append("\"\(keyword)\"") }
        if let listingCategory { parts.append(listingCategory.displayName) }
        if let listingSource { parts.append(listingSource.displayName) }
        if let priceMin, let priceMax {
            parts.append("$\(Int(priceMin))-$\(Int(priceMax))")
        } else if let priceMin {
            parts.append("$\(Int(priceMin))+")
        } else if let priceMax {
            parts.append("up to $\(Int(priceMax))")
        }
        return parts.isEmpty ? "All listings" : parts.joined(separator: " · ")
    }
}
