import Foundation

struct EbaySearchCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var isEnabled: Bool
}
