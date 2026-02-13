import Foundation

enum ListingStatus: String, Codable, Hashable, Sendable {
    case forSale = "for_sale"
    case forSaleOrTrade = "for_sale_or_trade"
    case sold
    case canceled

    var displayName: String {
        switch self {
        case .forSale: "For Sale"
        case .forSaleOrTrade: "For Sale or Trade"
        case .sold: "SOLD"
        case .canceled: "Canceled"
        }
    }
}
