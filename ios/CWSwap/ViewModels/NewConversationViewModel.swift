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

    init(recipient: String = "", title: String = "") {
        self.recipient = recipient
        self.title = title
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
        } catch {
            self.error = error
        }

        isSending = false
    }
}
