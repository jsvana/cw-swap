import Foundation

final class EbayScraper: Sendable {
    private let session: URLSession
    private let authManager: EbayAuthManager

    init(session: URLSession = .shared, authManager: EbayAuthManager = EbayAuthManager()) {
        self.session = session
        self.authManager = authManager
    }

    func fetchListings(
        page: Int = 1,
        query: String? = nil,
        categoryIds: [String] = []
    ) async throws -> [Listing] {
        guard !EbayConfig.clientId.isEmpty, EbayConfig.clientId != "YOUR_EBAY_CLIENT_ID" else {
            throw EbayError.notConfigured
        }
        guard !categoryIds.isEmpty else { return [] }

        let token = try await authManager.validToken()

        // eBay Browse API only allows 1 category per request,
        // so we make parallel requests per category and merge results.
        var allListings: [Listing] = []
        var seenIds: Set<String> = []

        try await withThrowingTaskGroup(of: [Listing].self) { group in
            for categoryId in categoryIds {
                group.addTask {
                    try await self.performSearch(
                        token: token,
                        page: page,
                        query: query,
                        categoryIds: [categoryId]
                    )
                }
            }

            for try await batch in group {
                for listing in batch {
                    if seenIds.insert(listing.id).inserted {
                        allListings.append(listing)
                    }
                }
            }
        }

        return allListings
    }

    // MARK: - Private

    private func performSearch(
        token: String,
        page: Int,
        query: String?,
        categoryIds: [String],
        isRetry: Bool = false
    ) async throws -> [Listing] {
        let offset = (page - 1) * EbayConfig.pageSize

        var components = URLComponents(string: EbayConfig.browseSearchURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "category_ids", value: categoryIds.joined(separator: ",")),
            URLQueryItem(name: "limit", value: String(EbayConfig.pageSize)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        let searchQuery = query ?? EbayConfig.defaultKeywords
        queryItems.append(URLQueryItem(name: "q", value: searchQuery))

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EbayError.apiFailed
        }

        // Retry once on 401
        if httpResponse.statusCode == 401, !isRetry {
            await authManager.invalidateToken()
            let newToken = try await authManager.validToken()
            return try await performSearch(
                token: newToken,
                page: page,
                query: query,
                categoryIds: categoryIds,
                isRetry: true
            )
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw EbayError.apiFailedWithDetails(statusCode: httpResponse.statusCode, body: body)
        }

        let searchResponse: EbaySearchResponse
        do {
            searchResponse = try JSONDecoder().decode(EbaySearchResponse.self, from: data)
        } catch {
            let raw = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw EbayError.apiFailedWithDetails(statusCode: 200, body: "Decode failed: \(error.localizedDescription) | Raw: \(raw)")
        }

        let items = searchResponse.itemSummaries ?? []
        return items.map(mapToListing)
    }

    private func mapToListing(_ item: EbayItemSummary) -> Listing {
        var photoUrls: [String] = []
        if let primary = item.image?.imageUrl, !primary.isEmpty {
            photoUrls.append(primary)
        }
        if let additional = item.additionalImages {
            photoUrls.append(contentsOf: additional.compactMap {
                $0.imageUrl.isEmpty ? nil : $0.imageUrl
            })
        }

        let amount = item.price.flatMap { Double($0.value) }
        let currency = item.price?.currency ?? "USD"
        let obo = item.buyingOptions?.contains("BEST_OFFER") ?? false

        let price: Price? = amount.map {
            Price(amount: $0, currency: currency, includesShipping: false, obo: obo)
        }

        let category = mapCategory(item.categories)

        return Listing(
            id: "ebay:\(item.itemId)",
            source: .ebay,
            sourceUrl: item.itemWebUrl ?? "",
            title: item.title,
            description: item.shortDescription ?? "",
            descriptionHtml: item.shortDescription ?? "",
            status: .forSale,
            callsign: item.seller?.username ?? "eBay Seller",
            memberId: nil,
            avatarUrl: nil,
            price: price,
            photoUrls: photoUrls,
            category: category,
            datePosted: Date(),
            dateModified: nil,
            replies: 0,
            views: 0,
            contactEmail: nil,
            contactPhone: nil,
            contactMethods: ["ebay"],
            auctionMeta: nil
        )
    }

    private func mapCategory(_ categories: [EbayCategory]?) -> ListingCategory? {
        guard let categories, let first = categories.first else { return .miscellaneous }
        let name = first.categoryName.lowercased()

        if name.contains("transceiver") || name.contains("radio") && !name.contains("antenna") && !name.contains("amplifier") {
            if name.contains("vhf") || name.contains("uhf") {
                return .vhfUhfRadios
            }
            if name.contains("antique") || name.contains("vintage") {
                return .antiqueRadios
            }
            return .hfRadios
        }
        if name.contains("antenna") {
            return name.contains("vhf") || name.contains("uhf") ? .vhfUhfAntennas : .hfAntennas
        }
        if name.contains("amplifier") {
            return name.contains("vhf") || name.contains("uhf") ? .vhfUhfAmplifiers : .hfAmplifiers
        }
        if name.contains("key") || name.contains("keyer") || name.contains("paddle") {
            return .keys
        }
        if name.contains("tower") || name.contains("mast") {
            return .towers
        }
        if name.contains("rotator") || name.contains("rotor") {
            return .rotators
        }
        if name.contains("test") || name.contains("meter") || name.contains("analyzer") {
            return .testEquipment
        }
        if name.contains("receiver") {
            return .hfRadios
        }
        if name.contains("part") || name.contains("accessor") {
            return .accessories
        }

        return .miscellaneous
    }
}
