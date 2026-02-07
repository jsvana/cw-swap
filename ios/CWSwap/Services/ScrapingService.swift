import Foundation

struct ScrapingService: Sendable {
    private let qrzScraper = QRZScraper()
    private let qthScraper = QTHScraper()

    func fetchListings(
        page: Int = 1,
        source: ListingSource? = nil,
        category: ListingCategory? = nil,
        query: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        hasPhoto: Bool? = nil,
        hideSold: Bool = true,
        sort: String? = nil
    ) async throws -> [Listing] {
        var allListings: [Listing] = []

        // Scrape from requested source(s)
        if source == nil || source == .qth {
            do {
                let qthListings = try await qthScraper.scrapeFullPage(page: page)
                allListings.append(contentsOf: qthListings)
            } catch {
                // QTH failure is non-fatal
            }
        }

        if source == nil || source == .qrz {
            do {
                let qrzListings = try await qrzScraper.scrapeFullPage(page: page)
                allListings.append(contentsOf: qrzListings)
            } catch {
                // QRZ failure is non-fatal if we have QTH results
                if allListings.isEmpty { throw error }
            }
        }

        // Apply in-memory filters
        var filtered = allListings

        if hideSold {
            filtered = filtered.filter { $0.status != .sold }
        }

        if let category {
            filtered = filtered.filter { $0.category == category }
        }

        if let query, !query.isEmpty {
            let lowered = query.lowercased()
            filtered = filtered.filter {
                $0.title.lowercased().contains(lowered)
                || $0.description.lowercased().contains(lowered)
                || $0.callsign.lowercased().contains(lowered)
            }
        }

        if let priceMin {
            filtered = filtered.filter { ($0.price?.amount ?? 0) >= priceMin }
        }
        if let priceMax {
            filtered = filtered.filter { ($0.price?.amount ?? Double.infinity) <= priceMax }
        }

        if hasPhoto == true {
            filtered = filtered.filter { $0.hasPhotos }
        }

        // Sort
        switch sort {
        case "oldest":
            filtered.sort { $0.datePosted < $1.datePosted }
        case "price_asc":
            filtered.sort { ($0.price?.amount ?? 0) < ($1.price?.amount ?? 0) }
        case "price_desc":
            filtered.sort { ($0.price?.amount ?? 0) > ($1.price?.amount ?? 0) }
        default: // newest
            filtered.sort { $0.datePosted > $1.datePosted }
        }

        return filtered
    }

    func fetchCategories() -> [CategoryInfo] {
        ListingCategory.allCases.map { category in
            CategoryInfo(
                category: category,
                displayName: category.displayName,
                sfSymbol: category.sfSymbol,
                listingCount: 0
            )
        }
    }

    func loginQRZ(username: String, password: String) async throws {
        try await qrzScraper.login(username: username, password: password)
    }
}
