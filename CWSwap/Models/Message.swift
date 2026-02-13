import Foundation

struct Message: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let conversationId: String
    let author: String
    let body: String
    let date: Date
    let avatarURL: String?
}
