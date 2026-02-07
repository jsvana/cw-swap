import Foundation
import Observation

@MainActor
@Observable
class ConversationsViewModel {
    private let authService = AuthenticationService()
    private let scraper = QRZScraper()

    var conversations: [Conversation] = []
    var isLoading = false
    var error: Error?

    var isLoggedIn: Bool {
        authService.isLoggedIn
    }

    func loadConversations() async {
        isLoading = true
        error = nil

        do {
            try await authService.reauthenticateIfNeeded()
            conversations = try await scraper.scrapeConversations()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
