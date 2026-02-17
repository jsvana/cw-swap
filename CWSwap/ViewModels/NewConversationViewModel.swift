import Foundation
import Observation

@MainActor
@Observable
class NewConversationViewModel {
    private let scraper = QRZScraper()
    private let authService = AuthenticationService()

    var recipient: String
    var title: String
    var messageBody = ""
    var isSending = false
    var error: Error?
    var didSend = false
    var listingUrl: String?

    init(recipient: String = "", title: String = "", listingUrl: String? = nil) {
        self.recipient = recipient
        self.title = title
        self.listingUrl = listingUrl
    }

    func send() async {
        let body = messageBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty, !title.isEmpty, !body.isEmpty else { return }

        isSending = true
        error = nil

        do {
            try await authService.reauthenticateIfNeeded()
            try await scraper.startConversation(
                recipient: recipient,
                title: title,
                message: body
            )
            didSend = true

            if let listingUrl {
                var mappings = UserDefaults.standard.dictionary(forKey: "conversationListingUrls") as? [String: String] ?? [:]
                mappings[title] = listingUrl
                UserDefaults.standard.set(mappings, forKey: "conversationListingUrls")
            }
        } catch {
            self.error = error
        }

        isSending = false
    }
}
