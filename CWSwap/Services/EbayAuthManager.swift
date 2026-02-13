import Foundation

actor EbayAuthManager {
    private var accessToken: String?
    private var tokenExpiry: Date?

    func validToken() async throws -> String {
        if let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }
        return try await fetchToken()
    }

    func invalidateToken() {
        accessToken = nil
        tokenExpiry = nil
    }

    private func fetchToken() async throws -> String {
        let credentials = "\(EbayConfig.clientId):\(EbayConfig.clientSecret)"
        guard let credentialData = credentials.data(using: .utf8) else {
            throw EbayError.tokenFailed
        }
        let base64Credentials = credentialData.base64EncodedString()

        guard let url = URL(string: EbayConfig.tokenURL) else {
            throw EbayError.tokenFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedScope = EbayConfig.scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? EbayConfig.scope
        let body = "grant_type=client_credentials&scope=\(encodedScope)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw EbayError.apiFailedWithDetails(statusCode: statusCode, body: "Token: \(responseBody)")
        }

        let tokenResponse = try JSONDecoder().decode(EbayTokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        // Expire 60s early to avoid edge cases
        tokenExpiry = Date().addingTimeInterval(Double(tokenResponse.expiresIn) - 60)
        return tokenResponse.accessToken
    }
}
