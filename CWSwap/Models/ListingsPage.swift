import Foundation

struct ListingsPage: Codable, Sendable {
    let listings: [Listing]
    let total: Int
    let page: Int
    let perPage: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case listings, total, page
        case perPage = "per_page"
        case hasMore = "has_more"
    }
}
