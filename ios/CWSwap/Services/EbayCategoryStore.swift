import Foundation
import Observation

@MainActor
@Observable
class EbayCategoryStore {
    private static let userDefaultsKey = "ebaySearchCategories"
    private static let seededKey = "ebaySearchCategoriesSeeded"

    var categories: [EbaySearchCategory] = []

    var enabledCategoryIds: [String] {
        categories.filter(\.isEnabled).map(\.id)
    }

    init() {
        loadFromDefaults()
        if !UserDefaults.standard.bool(forKey: Self.seededKey) {
            seedDefaults()
        }
    }

    func toggle(_ category: EbaySearchCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].isEnabled.toggle()
        saveToDefaults()
    }

    func add(_ category: EbaySearchCategory) {
        guard !categories.contains(where: { $0.id == category.id }) else { return }
        categories.append(category)
        saveToDefaults()
    }

    func remove(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        saveToDefaults()
    }

    func searchCategories(query: String) async throws -> [EbaySearchCategory] {
        guard !query.isEmpty else { return [] }

        let authManager = EbayAuthManager()
        let token = try await authManager.validToken()

        var components = URLComponents(string: EbayConfig.taxonomySearchURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw EbayError.apiFailedWithDetails(statusCode: statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(EbayCategorySuggestionResponse.self, from: data)
        return decoded.categorySuggestions?.map { suggestion in
            EbaySearchCategory(
                id: suggestion.category.categoryId,
                name: suggestion.category.categoryName,
                isEnabled: true
            )
        } ?? []
    }

    // MARK: - Persistence

    /// Reload categories from UserDefaults.
    /// Call this before scraping to pick up changes made by other store instances (e.g. Settings).
    func reloadFromDefaults() {
        loadFromDefaults()
    }

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else { return }
        categories = (try? JSONDecoder().decode([EbaySearchCategory].self, from: data)) ?? []
    }

    private func saveToDefaults() {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }

    private func seedDefaults() {
        categories = EbayConfig.defaultCategories
        saveToDefaults()
        UserDefaults.standard.set(true, forKey: Self.seededKey)
    }
}
