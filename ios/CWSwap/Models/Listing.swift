import CryptoKit
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
    let contactEmail: String?
    let contactPhone: String?
    let contactMethods: [String]

    enum CodingKeys: String, CodingKey {
        case id, source, title, description, status, callsign, price, replies, views, category
        case sourceUrl = "source_url"
        case descriptionHtml = "description_html"
        case memberId = "member_id"
        case avatarUrl = "avatar_url"
        case photoUrls = "photo_urls"
        case datePosted = "date_posted"
        case dateModified = "date_modified"
        case contactEmail = "contact_email"
        case contactPhone = "contact_phone"
        case contactMethods = "contact_methods"
    }

    var hasPhotos: Bool { !photoUrls.isEmpty }
    var hasContactInfo: Bool { contactEmail != nil || contactPhone != nil || !contactMethods.isEmpty }

    var contentHash: String {
        var parts = [title, description, status.rawValue, callsign]
        if let price {
            parts.append("\(price.amount)|\(price.currency)|\(price.includesShipping)|\(price.obo)")
        }
        parts.append(contentsOf: photoUrls)
        if let contactEmail { parts.append(contactEmail) }
        if let contactPhone { parts.append(contactPhone) }
        parts.append(contentsOf: contactMethods)
        let joined = parts.joined(separator: "\u{1F}")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    var firstPhotoUrl: URL? {
        photoUrls.lazy.compactMap { URL(string: $0) }.first
    }

    func photoURL(at index: Int) -> URL? {
        guard photoUrls.indices.contains(index) else { return nil }
        return URL(string: photoUrls[index])
    }

    var avatarURL: URL? {
        avatarUrl.flatMap { URL(string: $0) }
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
