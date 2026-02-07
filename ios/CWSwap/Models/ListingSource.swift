import Foundation

enum ListingSource: String, Codable, Hashable, CaseIterable, Sendable {
    case qrz
    case qth

    var displayName: String {
        switch self {
        case .qrz: "QRZ"
        case .qth: "QTH"
        }
    }
}
