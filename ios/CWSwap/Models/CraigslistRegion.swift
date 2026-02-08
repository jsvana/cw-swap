import Foundation

struct CraigslistRegion: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var isEnabled: Bool
    let latitude: Double
    let longitude: Double
}
