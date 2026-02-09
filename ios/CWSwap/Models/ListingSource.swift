import Foundation

enum ListingSource: String, Codable, Hashable, CaseIterable, Sendable {
    case qrz
    case qth
    case hamestate

    var displayName: String {
        switch self {
        case .qrz: "QRZ"
        case .qth: "QTH"
        case .hamestate: "HamEstate"
        }
    }
}
