import Foundation
import KeychainAccess

struct KeychainManager: Sendable {
    private static let serviceName = "com.jsvana.cwswap"
    private static let usernameKey = "qrz_username"
    private static let passwordKey = "qrz_password"

    private nonisolated(unsafe) let keychain = Keychain(service: serviceName)

    var storedUsername: String? {
        try? keychain.get(Self.usernameKey)
    }

    var storedPassword: String? {
        try? keychain.get(Self.passwordKey)
    }

    var hasCredentials: Bool {
        storedUsername != nil && storedPassword != nil
    }

    func saveCredentials(username: String, password: String) throws {
        try keychain.set(username, key: Self.usernameKey)
        try keychain.set(password, key: Self.passwordKey)
    }

    func deleteCredentials() throws {
        try keychain.remove(Self.usernameKey)
        try keychain.remove(Self.passwordKey)
    }
}
