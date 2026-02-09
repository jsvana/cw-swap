import Foundation

final class HamEstateScraper: Sendable {
    private static let apiBaseURL = "https://www.hamestate.com/wp-json/wc/store/v1/products"
    private static let siteBaseURL = "https://www.hamestate.com"
    private static let perPage = 25
    /// WooCommerce category ID for ham_equipment root
    private static let hamEquipmentCategoryId = 19

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func scrapeFullPage(page: Int) async throws -> [Listing] {
        let products = try await fetchProducts(page: max(page, 1))
        return products.map { mapToListing($0) }
    }

    func scrapeFullPage(
        page: Int,
        onListing: (Listing) -> Void,
        onProgress: (Int, Int) -> Void
    ) async throws {
        onProgress(0, 1)
        let products = try await fetchProducts(page: max(page, 1))
        for product in products {
            onListing(mapToListing(product))
        }
        onProgress(1, 1)
    }

    // MARK: - API Fetching

    private func fetchProducts(page: Int) async throws -> [StoreProduct] {
        var components = URLComponents(string: Self.apiBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: String(Self.perPage)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "category", value: String(Self.hamEquipmentCategoryId)),
        ]

        guard let url = components.url else {
            throw ScraperError.parseFailed("Could not construct HamEstate API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            // Empty page or bad request
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 400 {
                return []
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw ScraperError.parseFailed("HamEstate API returned status \(httpResponse.statusCode)")
            }
        }

        do {
            return try JSONDecoder().decode([StoreProduct].self, from: data)
        } catch {
            let raw = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw ScraperError.parseFailed("HamEstate API decode failed: \(error.localizedDescription) | Raw: \(raw)")
        }
    }

    // MARK: - Mapping

    private func mapToListing(_ product: StoreProduct) -> Listing {
        let price = Self.extractPrice(from: product.prices)
        let photoUrls = product.images.map(\.src)
        let status: ListingStatus = product.is_in_stock ? .forSale : .sold
        let category = Self.mapCategory(product.categories)

        // Strip HTML from description
        let description = Self.stripHTML(product.description)
        let shortDesc = Self.stripHTML(product.short_description)
        let displayDescription = description.isEmpty ? shortDesc : description

        return Listing(
            id: "hamestate:\(product.id)",
            source: .hamestate,
            sourceUrl: product.permalink,
            title: product.name,
            description: displayDescription,
            descriptionHtml: product.description,
            status: status,
            callsign: "",
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
            contactMethods: []
        )
    }

    // MARK: - Price Extraction

    private static func extractPrice(from prices: StorePrices?) -> Price? {
        guard let prices, let rawValue = Int(prices.price), rawValue > 0 else {
            return nil
        }
        let divisor = pow(10.0, Double(prices.currency_minor_unit))
        let amount = Double(rawValue) / divisor
        guard amount >= 0.01, amount <= 500_000 else { return nil }

        let isOnSale = !prices.sale_price.isEmpty && prices.sale_price != prices.regular_price
        return Price(amount: amount, currency: prices.currency_code, includesShipping: false, obo: isOnSale)
    }

    // MARK: - Category Mapping

    private static let slugCategoryMap: [String: ListingCategory] = [
        "hf_rigs": .hfRadios,
        "vhf_uhf_rigs": .vhfUhfRadios,
        "vhf_uhf_rigs_portable": .vhfUhfRadios,
        "amps": .hfAmplifiers,
        "hf_antennas": .hfAntennas,
        "antennas-vhf-uhf": .vhfUhfAntennas,
        "antennas-parts": .vhfUhfAntennas,
        "towers": .towers,
        "crankup_towers": .towers,
        "antenna_rotators": .rotators,
        "keys-keyers": .keys,
        "test_gear": .testEquipment,
        "computers-accessories": .computers,
        "collins": .antiqueRadios,
        "vintage-parts": .antiqueRadios,
        "accessories": .accessories,
        "microphones_speakers": .accessories,
        "speakers": .accessories,
        "headphones": .accessories,
        "cables_prep-tools": .accessories,
        "power-supplies": .accessories,
        "tuners": .accessories,
        "dummyloads-filters": .accessories,
        "switches_controllers": .accessories,
        "grounding_surge": .accessories,
    ]

    private static func mapCategory(_ categories: [StoreCategory]) -> ListingCategory? {
        for cat in categories {
            if let mapped = slugCategoryMap[cat.slug] {
                return mapped
            }
        }
        return categories.isEmpty ? nil : .miscellaneous
    }

    // MARK: - HTML Stripping

    private static let htmlTagRegex = try! NSRegularExpression(pattern: "<[^>]+>")

    private static func stripHTML(_ html: String) -> String {
        let range = NSRange(html.startIndex..., in: html)
        let stripped = htmlTagRegex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
        // Decode common HTML entities
        return stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - WC Store API Models

private struct StoreProduct: Decodable {
    let id: Int
    let name: String
    let permalink: String
    let description: String
    let short_description: String
    let prices: StorePrices?
    let images: [StoreImage]
    let categories: [StoreCategory]
    let is_in_stock: Bool
}

private struct StorePrices: Decodable {
    let price: String
    let regular_price: String
    let sale_price: String
    let currency_code: String
    let currency_minor_unit: Int
}

private struct StoreImage: Decodable {
    let src: String
    let thumbnail: String
    let alt: String
}

private struct StoreCategory: Decodable {
    let id: Int
    let name: String
    let slug: String
}
