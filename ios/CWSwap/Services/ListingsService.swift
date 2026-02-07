import Foundation

struct ListingsService: Sendable {
    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func fetchListings(
        page: Int = 1,
        perPage: Int = 20,
        source: ListingSource? = nil,
        category: ListingCategory? = nil,
        query: String? = nil,
        callsign: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        hasPhoto: Bool? = nil,
        sort: String? = nil
    ) async throws -> ListingsPage {
        var params: [String: String] = [
            "page": "\(page)",
            "per_page": "\(perPage)",
        ]
        if let source { params["source"] = source.rawValue }
        if let category { params["category"] = category.rawValue }
        if let query, !query.isEmpty { params["q"] = query }
        if let callsign, !callsign.isEmpty { params["callsign"] = callsign }
        if let priceMin { params["price_min"] = "\(priceMin)" }
        if let priceMax { params["price_max"] = "\(priceMax)" }
        if let hasPhoto { params["has_photo"] = "\(hasPhoto)" }
        if let sort { params["sort"] = sort }

        return try await api.fetch("/api/v1/listings", query: params)
    }

    func fetchListing(id: String) async throws -> Listing {
        try await api.fetch("/api/v1/listings/\(id)")
    }

    func fetchCategories() async throws -> [CategoryInfo] {
        try await api.fetch("/api/v1/categories")
    }
}
