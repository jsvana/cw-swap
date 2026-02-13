import Foundation

enum ListingSource: String, Codable, Hashable, CaseIterable, Sendable {
    case qrz
    case qth
    case hamestate
    case ebay
    case craigslist
    case hibid

    var displayName: String {
        switch self {
        case .qrz: "QRZ"
        case .qth: "QTH"
        case .hamestate: "HamEstate"
        case .ebay: "eBay"
        case .craigslist: "Craigslist"
        case .hibid: "HiBid"
        }
    }

    var isAuction: Bool {
        self == .hibid
    }
}
