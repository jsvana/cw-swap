import Foundation
import SwiftData

@Model
final class PersistedListing {
    @Attribute(.unique) var id: String = ""
    var source: String = ""
    var sourceUrl: String = ""
    var title: String = ""
    var listingDescription: String = ""
    var descriptionHtml: String = ""
    var status: String = ""
    var callsign: String = ""
    var memberId: Int?
    var avatarUrl: String?
    var priceAmount: Double?
    var priceCurrency: String?
    var priceIncludesShipping: Bool = false
    var priceObo: Bool = false
    var photoUrlsData: Data = Data()
    var category: String?
    var datePosted: Date = Date()
    var dateModified: Date?
    var replies: Int = 0
    var views: Int = 0
    var contactEmail: String?
    var contactPhone: String?
    var contactMethodsData: Data = Data()
    var contentHash: String = ""
    var dateScraped: Date = Date()
    var isBookmarked: Bool = false

    init() {}

    init(from listing: Listing) {
        self.id = listing.id
        self.source = listing.source.rawValue
        self.sourceUrl = listing.sourceUrl
        self.title = listing.title
        self.listingDescription = listing.description
        self.descriptionHtml = listing.descriptionHtml
        self.status = listing.status.rawValue
        self.callsign = listing.callsign
        self.memberId = listing.memberId
        self.avatarUrl = listing.avatarUrl
        self.priceAmount = listing.price?.amount
        self.priceCurrency = listing.price?.currency
        self.priceIncludesShipping = listing.price?.includesShipping ?? false
        self.priceObo = listing.price?.obo ?? false
        self.photoUrlsData = (try? JSONEncoder().encode(listing.photoUrls)) ?? Data()
        self.category = listing.category?.rawValue
        self.datePosted = listing.datePosted
        self.dateModified = listing.dateModified
        self.replies = listing.replies
        self.views = listing.views
        self.contactEmail = listing.contactEmail
        self.contactPhone = listing.contactPhone
        self.contactMethodsData = (try? JSONEncoder().encode(listing.contactMethods)) ?? Data()
        self.contentHash = listing.contentHash
        self.dateScraped = Date()
    }

    func toListing() -> Listing {
        let photoUrls = (try? JSONDecoder().decode([String].self, from: photoUrlsData)) ?? []
        let contactMethods = (try? JSONDecoder().decode([String].self, from: contactMethodsData)) ?? []
        let price: Price? = if let amount = priceAmount, let currency = priceCurrency {
            Price(amount: amount, currency: currency, includesShipping: priceIncludesShipping, obo: priceObo)
        } else {
            nil
        }

        return Listing(
            id: id,
            source: ListingSource(rawValue: source) ?? .qrz,
            sourceUrl: sourceUrl,
            title: title,
            description: listingDescription,
            descriptionHtml: descriptionHtml,
            status: ListingStatus(rawValue: status) ?? .forSale,
            callsign: callsign,
            memberId: memberId,
            avatarUrl: avatarUrl,
            price: price,
            photoUrls: photoUrls,
            category: category.flatMap { ListingCategory(rawValue: $0) },
            datePosted: datePosted,
            dateModified: dateModified,
            replies: replies,
            views: views,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            contactMethods: contactMethods
        )
    }
}
