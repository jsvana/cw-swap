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

    func login(username: String, password: String) async throws -> LoginResult {
        let result = try await scraper.login(username: username, password: password)
        if case .success = result {
            try keychain.saveCredentials(username: username, password: password)
        }
        return result
    }

    func submitTwoFactorCode(
        _ code: String,
        challenge: TwoFactorChallenge,
        username: String,
        password: String
    ) async throws {
        try await scraper.submitTwoFactorCode(code, challenge: challenge, username: username, password: password)
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
        let result = try await scraper.login(username: username, password: password)
        if case .twoFactorRequired = result {
            throw ScraperError.loginFailed(
                "Session expired — please log in again to complete two-factor authentication"
            )
        }
    }
}
