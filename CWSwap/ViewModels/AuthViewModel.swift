import Foundation
import Observation

@MainActor
@Observable
class AuthViewModel {
    private let authService = AuthenticationService()

    var username = ""
    var password = ""
    var twoFactorCode = ""
    var isLoading = false
    var error: Error?
    var loginSucceeded = false
    var needsTwoFactor = false
    private var twoFactorChallenge: TwoFactorChallenge?

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
            let result = try await authService.login(username: username, password: password)
            switch result {
            case .success:
                loginSucceeded = true
                username = ""
                password = ""
            case .twoFactorRequired(let challenge):
                twoFactorChallenge = challenge
                needsTwoFactor = true
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func submitTwoFactorCode() async {
        guard let challenge = twoFactorChallenge, !twoFactorCode.isEmpty else { return }
        isLoading = true
        error = nil

        do {
            try await authService.submitTwoFactorCode(
                twoFactorCode,
                challenge: challenge,
                username: username,
                password: password
            )
            loginSucceeded = true
            username = ""
            password = ""
            twoFactorCode = ""
            twoFactorChallenge = nil
            needsTwoFactor = false
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func cancelTwoFactor() {
        needsTwoFactor = false
        twoFactorChallenge = nil
        twoFactorCode = ""
        error = nil
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
