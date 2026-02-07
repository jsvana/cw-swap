import Foundation

struct Conversation: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let slug: String
    let starterCallsign: String
    let participants: [String]
    let replyCount: Int
    let participantCount: Int
    let lastPoster: String
    let createdDate: Date
    let lastReplyDate: Date
    let avatarURL: String?

    var url: String {
        "https://forums.qrz.com/index.php?conversations/\(slug).\(id)/"
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastReplyDate, relativeTo: .now)
    }
}
