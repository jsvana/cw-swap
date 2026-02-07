import Foundation

struct AuthenticationService: Sendable {
    private let keychain = KeychainManager()
    private let scraper = QRZScraper()

    var isLoggedIn: Bool {
        keychain.hasCredentials
    }

    var storedUsername: String? {
        keychain.storedUsername
    }

    func login(username: String, password: String) async throws {
        try await scraper.login(username: username, password: password)
        try keychain.saveCredentials(username: username, password: password)
    }

    func logout() throws {
        try keychain.deleteCredentials()
        // Clear cookies for QRZ domains
        if let cookieStorage = URLSession.shared.configuration.httpCookieStorage {
            for cookie in cookieStorage.cookies ?? [] {
                if let domain = cookie.domain as String?,
                   domain.contains("qrz.com") {
                    cookieStorage.deleteCookie(cookie)
                }
            }
        }
    }

    func reauthenticateIfNeeded() async throws {
        guard let username = keychain.storedUsername,
              let password = keychain.storedPassword else {
            return
        }
        try await scraper.login(username: username, password: password)
    }
}
