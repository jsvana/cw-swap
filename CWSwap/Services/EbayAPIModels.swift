import Foundation

// MARK: - Browse API Response

struct EbaySearchResponse: Decodable, Sendable {
    let total: Int?
    let next: String?
    let offset: Int?
    let limit: Int?
    let itemSummaries: [EbayItemSummary]?
}

struct EbayItemSummary: Decodable, Sendable {
    let itemId: String
    let title: String
    let price: EbayPrice?
    let image: EbayImage?
    let additionalImages: [EbayImage]?
    let condition: String?
    let itemWebUrl: String?
    let seller: EbaySeller?
    let categories: [EbayCategory]?
    let buyingOptions: [String]?
    let shortDescription: String?
    let itemLocation: EbayLocation?
}

struct EbayPrice: Decodable, Sendable {
    let value: String
    let currency: String
}

struct EbayImage: Decodable, Sendable {
    let imageUrl: String
}

struct EbaySeller: Decodable, Sendable {
    let username: String?
    let feedbackPercentage: String?
    let feedbackScore: Int?
}

struct EbayCategory: Decodable, Sendable {
    let categoryId: String
    let categoryName: String
}

struct EbayLocation: Decodable, Sendable {
    let postalCode: String?
    let country: String?
}

// MARK: - Taxonomy API Response

struct EbayCategorySuggestionResponse: Decodable, Sendable {
    let categorySuggestions: [EbayCategorySuggestion]?
}

struct EbayCategorySuggestion: Decodable, Sendable {
    let category: EbaySuggestedCategory
    let categoryTreeNodeLevel: Int?
}

struct EbaySuggestedCategory: Decodable, Sendable {
    let categoryId: String
    let categoryName: String
}

// MARK: - Token Response

struct EbayTokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Errors

enum EbayError: LocalizedError {
    case tokenFailed
    case apiFailed
    case apiFailedWithDetails(statusCode: Int, body: String)
    case decodingFailed
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .tokenFailed: "eBay authentication failed. Try again later."
        case .apiFailed: "eBay search failed. Try again later."
        case .apiFailedWithDetails: "eBay search temporarily unavailable."
        case .decodingFailed: "Unexpected eBay response. Try again later."
        case .notConfigured: "eBay API credentials not configured."
        }
    }
}
