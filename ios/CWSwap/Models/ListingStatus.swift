import Foundation

enum ListingStatus: String, Codable, Hashable, Sendable {
    case forSale = "for_sale"
    case sold
    case canceled

    var displayName: String {
        switch self {
        case .forSale: "For Sale"
        case .sold: "SOLD"
        case .canceled: "Canceled"
        }
    }
}
