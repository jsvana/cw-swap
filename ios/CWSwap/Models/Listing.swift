import Foundation

struct Listing: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let source: ListingSource
    let sourceUrl: String
    let title: String
    let description: String
    let descriptionHtml: String
    let status: ListingStatus
    let callsign: String
    let memberId: Int?
    let avatarUrl: String?
    let price: Price?
    let photoUrls: [String]
    let category: ListingCategory?
    let datePosted: Date
    let dateModified: Date?
    let replies: Int
    let views: Int

    enum CodingKeys: String, CodingKey {
        case id, source, title, description, status, callsign, price, replies, views, category
        case sourceUrl = "source_url"
        case descriptionHtml = "description_html"
        case memberId = "member_id"
        case avatarUrl = "avatar_url"
        case photoUrls = "photo_urls"
        case datePosted = "date_posted"
        case dateModified = "date_modified"
    }

    var hasPhotos: Bool { !photoUrls.isEmpty }

    var firstPhotoUrl: URL? {
        photoUrls.first.flatMap { APIClient.shared.proxyImageURL(for: $0) }
    }

    func proxyPhotoURL(at index: Int) -> URL? {
        guard photoUrls.indices.contains(index) else { return nil }
        return APIClient.shared.proxyImageURL(for: photoUrls[index])
    }

    var proxyAvatarUrl: URL? {
        avatarUrl.flatMap { APIClient.shared.proxyImageURL(for: $0) }
    }

    var sourceURL: URL? { URL(string: sourceUrl) }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: datePosted, relativeTo: .now)
    }

    var formattedPrice: String? {
        guard let price else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = price.currency
        formatter.maximumFractionDigits = price.amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        var text = formatter.string(from: NSNumber(value: price.amount)) ?? "$\(Int(price.amount))"
        if price.obo { text += " OBO" }
        if price.includesShipping { text += " shipped" }
        return text
    }
}
