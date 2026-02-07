import Foundation

struct CategoryInfo: Identifiable, Codable, Sendable {
    let category: ListingCategory
    let displayName: String
    let sfSymbol: String
    let listingCount: Int

    var id: String { category.rawValue }

    enum CodingKeys: String, CodingKey {
        case category
        case displayName = "display_name"
        case sfSymbol = "sf_symbol"
        case listingCount = "listing_count"
    }
}
