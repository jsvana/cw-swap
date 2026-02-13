import Foundation
import Observation

@MainActor
@Observable
class AuthViewModel {
    private let authService = AuthenticationService()

    var username = ""
    var password = ""
    var isLoading = false
    var error: Error?
    var loginSucceeded = false

    var isLoggedIn: Bool {
        authService.isLoggedIn
    }

    var storedUsername: String? {
        authService.storedUsername
    }

    func login() async {
        guard !username.isEmpty, !password.isEmpty else { return }
        isLoading = true
        error = nil

        do {
            try await authService.login(username: username, password: password)
            loginSucceeded = true
            username = ""
            password = ""
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func logout() {
        do {
            try authService.logout()
            loginSucceeded = false
        } catch {
            self.error = error
        }
    }
}
