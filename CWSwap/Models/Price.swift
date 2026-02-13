import Foundation

struct Price: Hashable, Codable, Sendable {
    let amount: Double
    let currency: String
    let includesShipping: Bool
    let obo: Bool

    enum CodingKeys: String, CodingKey {
        case amount, currency, obo
        case includesShipping = "includes_shipping"
    }
}
