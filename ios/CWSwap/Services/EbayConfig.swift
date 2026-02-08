import Foundation

enum EbayConfig {
    // MARK: - API Credentials (loaded from Info.plist via Secrets.xcconfig)
    static let clientId: String = Bundle.main.object(forInfoDictionaryKey: "EbayClientId") as? String ?? ""
    static let clientSecret: String = Bundle.main.object(forInfoDictionaryKey: "EbayClientSecret") as? String ?? ""

    // MARK: - Endpoints
    static let tokenURL = "https://api.ebay.com/identity/v1/oauth2/token"
    static let browseSearchURL = "https://api.ebay.com/buy/browse/v1/item_summary/search"
    static let taxonomySearchURL = "https://api.ebay.com/commerce/taxonomy/v1/category_tree/0/get_category_suggestions"

    // MARK: - Defaults
    static let scope = "https://api.ebay.com/oauth/api_scope"
    static let defaultKeywords = "ham radio"
    static let pageSize = 50

    static let defaultCategories: [EbaySearchCategory] = [
        EbaySearchCategory(id: "175726", name: "Ham Radio Transceivers", isEnabled: true),
        EbaySearchCategory(id: "175710", name: "Ham Radio Antennas", isEnabled: true),
        EbaySearchCategory(id: "175712", name: "Ham Radio Amplifiers", isEnabled: true),
        EbaySearchCategory(id: "175741", name: "Ham Radio Parts & Accessories", isEnabled: true),
        EbaySearchCategory(id: "175742", name: "Ham Radio Receivers", isEnabled: true),
        EbaySearchCategory(id: "4670", name: "Ham Radio Equipment", isEnabled: true),
    ]
}
