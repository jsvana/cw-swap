import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .httpError(let code): "Server error (\(code))"
        case .decodingError(let err): "Data error: \(err.localizedDescription)"
        case .networkError(let err): "Network error: \(err.localizedDescription)"
        }
    }
}

final class APIClient: Sendable {
    static let shared = APIClient()

    static let serverURLKey = "serverURL"
    static let defaultServerURL = "http://localhost:8080"

    private let session: URLSession

    var baseURL: String {
        UserDefaults.standard.string(forKey: Self.serverURLKey) ?? Self.defaultServerURL
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func proxyImageURL(for originalURL: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)/api/v1/proxy/image")
        components?.queryItems = [URLQueryItem(name: "url", value: originalURL)]
        return components?.url
    }

    func fetch<T: Decodable & Sendable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "\(baseURL)\(path)")
        if !query.isEmpty {
            components?.queryItems = query.compactMap { key, value in
                value.isEmpty ? nil : URLQueryItem(name: key, value: value)
            }
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw APIError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
