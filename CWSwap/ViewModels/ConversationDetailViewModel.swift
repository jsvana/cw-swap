import Foundation
import Observation

@MainActor
@Observable
class ConversationDetailViewModel {
    private let scraper = QRZScraper()
    private let authService = AuthenticationService()

    let conversation: Conversation
    var messages: [Message] = []
    var replyText = ""
    var isLoading = false
    var isSending = false
    var error: Error?

    var currentUsername: String? {
        authService.storedUsername
    }

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    func loadMessages() async {
        isLoading = true
        error = nil

        do {
            messages = try await scraper.scrapeConversation(
                id: conversation.id,
                slug: conversation.slug
            )
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func sendReply() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        error = nil

        do {
            try await scraper.replyToConversation(
                id: conversation.id,
                slug: conversation.slug,
                message: text
            )
            replyText = ""
            await loadMessages()
        } catch {
            self.error = error
        }

        isSending = false
    }
}
