import Foundation

struct CraigslistSearchTerm: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let term: String
    var isEnabled: Bool
}
