import Foundation
import SwiftSoup

final class CraigslistScraper: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    func scrapeFullPage(
        regions: [CraigslistRegion],
        terms: [CraigslistSearchTerm]
    ) async throws -> [Listing] {
        var listings: [Listing] = []
        try await scrapeFullPage(
            regions: regions,
            terms: terms,
            onListing: { listing in listings.append(listing) },
            onProgress: { _, _ in }
        )
        return listings
    }

    /// Progressive variant: yields listings as they arrive with progress updates.
    func scrapeFullPage(
        regions: [CraigslistRegion],
        terms: [CraigslistSearchTerm],
        onListing: (Listing) -> Void,
        onProgress: (Int, Int) -> Void
    ) async throws {
        let enabledRegions = regions.filter(\.isEnabled)
        let enabledTerms = terms.filter(\.isEnabled)
        guard !enabledRegions.isEmpty, !enabledTerms.isEmpty else { return }

        // Phase 1: Fetch search pages for all (region, term) combos in parallel
        let searchListings = await fetchAllSearchPages(regions: enabledRegions, terms: enabledTerms)

        // Deduplicate by Craigslist post ID (strip region prefix)
        var seen = Set<String>()
        var uniqueListings: [Listing] = []
        for listing in searchListings {
            let postId = Self.extractPostId(from: listing.id)
            if seen.insert(postId).inserted {
                uniqueListings.append(listing)
            }
        }

        let total = uniqueListings.count
        onProgress(0, total)

        // Phase 2: Fetch detail pages concurrently for photos
        var completed = 0
        let maxConcurrency = CraigslistConfig.maxConcurrentDetailFetches

        await withTaskGroup(of: Listing?.self) { group in
            var nextIndex = 0

            // Seed initial batch
            while nextIndex < min(maxConcurrency, uniqueListings.count) {
                let listing = uniqueListings[nextIndex]
                nextIndex += 1
                group.addTask { await self.enrichWithDetailPage(listing) }
            }

            // Process results as they arrive, enqueue more work
            for await enriched in group {
                completed += 1
                onProgress(completed, total)
                if let enriched {
                    onListing(enriched)
                }

                if nextIndex < uniqueListings.count {
                    let listing = uniqueListings[nextIndex]
                    nextIndex += 1
                    group.addTask { await self.enrichWithDetailPage(listing) }
                }
            }
        }
    }

    // MARK: - Search Page Fetching

    private func fetchAllSearchPages(
        regions: [CraigslistRegion],
        terms: [CraigslistSearchTerm]
    ) async -> [Listing] {
        await withTaskGroup(of: [Listing].self) { group in
            for region in regions {
                for term in terms {
                    group.addTask {
                        await self.fetchSearchPage(region: region, term: term)
                    }
                }
            }

            var all: [Listing] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }
    }

    private func fetchSearchPage(region: CraigslistRegion, term: CraigslistSearchTerm) async -> [Listing] {
        guard let url = CraigslistConfig.searchURL(region: region.id, query: term.term) else {
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return []
            }

            let doc = try SwiftSoup.parse(html)

            // Try JSON-LD structured data first (most reliable)
            let jsonLdListings = try parseJsonLd(doc, region: region)
            if !jsonLdListings.isEmpty {
                // Merge detail URLs from HTML links
                let urlMap = try extractDetailURLs(from: doc)
                return jsonLdListings.map { listing in
                    if let detailUrl = urlMap[Self.extractPostId(from: listing.id)], listing.sourceUrl.isEmpty {
                        return Listing(
                            id: listing.id,
                            source: listing.source,
                            sourceUrl: detailUrl,
                            title: listing.title,
                            description: listing.description,
                            descriptionHtml: listing.descriptionHtml,
                            status: listing.status,
                            callsign: listing.callsign,
                            memberId: listing.memberId,
                            avatarUrl: listing.avatarUrl,
                            price: listing.price,
                            photoUrls: listing.photoUrls,
                            category: listing.category,
                            datePosted: listing.datePosted,
                            dateModified: listing.dateModified,
                            replies: listing.replies,
                            views: listing.views,
                            contactEmail: listing.contactEmail,
                            contactPhone: listing.contactPhone,
                            contactMethods: listing.contactMethods
                        )
                    }
                    return listing
                }
            }

            // Fallback: parse static HTML search results
            return try parseStaticHTML(doc, region: region)
        } catch {
            return []
        }
    }

    // MARK: - JSON-LD Parsing

    /// JSON-LD item structure from Craigslist search pages.
    private struct JsonLdItemList: Decodable {
        let itemListElement: [JsonLdListItem]?
    }

    private struct JsonLdListItem: Decodable {
        let item: JsonLdProduct?
    }

    private struct JsonLdProduct: Decodable {
        let name: String?
        let url: String?
        let image: [String]?
        let offers: JsonLdOffer?
    }

    private struct JsonLdOffer: Decodable {
        let price: JsonLdPrice?
        let priceCurrency: String?
        let availableAtOrFrom: JsonLdLocation?

        enum CodingKeys: String, CodingKey {
            case price, priceCurrency, availableAtOrFrom
        }
    }

    /// Price can be a string or number in the JSON.
    private enum JsonLdPrice: Decodable {
        case string(String)
        case number(Double)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .string(s)
            } else if let n = try? container.decode(Double.self) {
                self = .number(n)
            } else {
                self = .string("0")
            }
        }

        var doubleValue: Double? {
            switch self {
            case .string(let s): Double(s)
            case .number(let n): n
            }
        }
    }

    private struct JsonLdLocation: Decodable {
        let address: JsonLdAddress?
    }

    private struct JsonLdAddress: Decodable {
        let addressLocality: String?
        let addressRegion: String?
    }

    private func parseJsonLd(_ doc: Document, region: CraigslistRegion) throws -> [Listing] {
        let scripts = try doc.select("script[type=application/ld+json]")
        for script in scripts {
            let jsonText = script.data()
            guard let jsonData = jsonText.data(using: .utf8) else { continue }

            // Try to decode as ItemList
            guard let itemList = try? JSONDecoder().decode(JsonLdItemList.self, from: jsonData),
                  let elements = itemList.itemListElement else {
                continue
            }

            return elements.compactMap { element -> Listing? in
                guard let product = element.item,
                      let name = product.name, !name.isEmpty else {
                    return nil
                }

                let sourceUrl = product.url ?? ""
                let postId = sourceUrl.isEmpty ? UUID().uuidString : Self.postIdFromURL(sourceUrl)
                let listingId = "craigslist:\(region.id):\(postId)"

                var price: Price?
                if let offerPrice = product.offers?.price?.doubleValue, offerPrice > 0 {
                    price = Price(
                        amount: offerPrice,
                        currency: product.offers?.priceCurrency ?? "USD",
                        includesShipping: false,
                        obo: false
                    )
                }

                let photoUrls = product.image ?? []
                let category = Self.mapCategory(title: name, description: "")

                return Listing(
                    id: listingId,
                    source: .craigslist,
                    sourceUrl: sourceUrl,
                    title: Self.cleanTitle(name),
                    description: "",
                    descriptionHtml: "",
                    status: .forSale,
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
        }
        return []
    }

    /// Extract post ID → detail URL mapping from HTML links.
    private func extractDetailURLs(from doc: Document) throws -> [String: String] {
        var urlMap: [String: String] = [:]
        let links = try doc.select("a[href]")
        for link in links {
            let href = try link.attr("href")
            // Match Craigslist detail URLs: /xxx/yyy/d/slug/12345.html or full URLs
            if href.contains("/d/") && href.hasSuffix(".html") {
                let postId = Self.postIdFromURL(href)
                if !postId.isEmpty {
                    // Ensure full URL
                    if href.hasPrefix("http") {
                        urlMap[postId] = href
                    } else if let base = try? doc.select("base[href]").first()?.attr("href") {
                        urlMap[postId] = base + href
                    }
                }
            }
        }
        return urlMap
    }

    // MARK: - Static HTML Fallback

    private func parseStaticHTML(_ doc: Document, region: CraigslistRegion) throws -> [Listing] {
        // Try the static search results list
        let resultRows = try doc.select("ol.cl-static-search-results li, .result-row, li[data-pid]")
        guard !resultRows.isEmpty() else { return [] }

        return try resultRows.compactMap { row -> Listing? in
            // Find the title link
            let titleLink = try row.select("a.result-title, a.hdrlnk, a[href*='/d/']").first()
            guard let titleLink else { return nil }

            let title = try titleLink.text()
            guard !title.isEmpty else { return nil }

            var href = try titleLink.attr("href")
            if !href.hasPrefix("http") {
                href = "https://\(region.id).craigslist.org\(href)"
            }

            let postId = Self.postIdFromURL(href)
            let listingId = "craigslist:\(region.id):\(postId)"

            // Price
            let priceText = try row.select(".result-price").first()?.text() ?? ""
            let price = PriceExtractor.extractPrice(from: priceText)

            let category = Self.mapCategory(title: title, description: "")

            return Listing(
                id: listingId,
                source: .craigslist,
                sourceUrl: href,
                title: Self.cleanTitle(title),
                description: "",
                descriptionHtml: "",
                status: .forSale,
                callsign: "",
                memberId: nil,
                avatarUrl: nil,
                price: price,
                photoUrls: [],
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
    }

    // MARK: - Detail Page Enrichment

    private func enrichWithDetailPage(_ listing: Listing) async -> Listing? {
        guard let url = URL(string: listing.sourceUrl), !listing.sourceUrl.isEmpty else { return listing }

        // Rate limiting delay
        try? await Task.sleep(for: .milliseconds(Int(CraigslistConfig.detailFetchDelay * 1000)))

        do {
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return listing
            }

            let doc = try SwiftSoup.parse(html)

            // Extract photos from gallery
            let photoUrls = try extractPhotos(from: doc)

            // Extract full description
            let descriptionHtml = try doc.select("#postingbody").first()?.html() ?? listing.descriptionHtml
            let description = try doc.select("#postingbody").first()?.text() ?? listing.description

            // Extract contact info from description
            let contactInfo = ContactInfoExtractor.extractAll(from: description)

            // Extract posting date
            let datePosted = try extractPostingDate(from: doc) ?? listing.datePosted

            return Listing(
                id: listing.id,
                source: .craigslist,
                sourceUrl: listing.sourceUrl,
                title: listing.title,
                description: description,
                descriptionHtml: descriptionHtml,
                status: listing.status,
                callsign: listing.callsign,
                memberId: nil,
                avatarUrl: nil,
                price: listing.price,
                photoUrls: photoUrls,
                category: listing.category,
                datePosted: datePosted,
                dateModified: listing.dateModified,
                replies: listing.replies,
                views: listing.views,
                contactEmail: contactInfo.email,
                contactPhone: contactInfo.phone,
                contactMethods: contactInfo.methods
            )
        } catch {
            return listing
        }
    }

    private func extractPhotos(from doc: Document) throws -> [String] {
        var photos: [String] = []

        // Look for gallery images in the thumbs section
        let thumbs = try doc.select(".gallery .thumb")
        for thumb in thumbs {
            if let href = try? thumb.attr("href"), !href.isEmpty {
                photos.append(href)
            }
        }

        // Method 2: Look for images in the swipe gallery
        if photos.isEmpty {
            let galleryImages = try doc.select(".gallery img, .slide img, #thumbs a")
            for img in galleryImages {
                if let src = try? img.attr("src"), !src.isEmpty, src.hasPrefix("http") {
                    photos.append(src)
                } else if let href = try? img.attr("href"), !href.isEmpty, href.hasPrefix("http") {
                    photos.append(href)
                }
            }
        }

        // Method 3: Look for image links in the iids data
        if photos.isEmpty {
            let imageLinks = try doc.select("a.thumb")
            for link in imageLinks {
                if let href = try? link.attr("href"), !href.isEmpty {
                    photos.append(href)
                }
            }
        }

        return photos
    }

    private func extractPostingDate(from doc: Document) throws -> Date? {
        // Craigslist detail pages have <time class="date timeago" datetime="2025-01-15T12:00:00-0800">
        guard let timeEl = try doc.select("time.date.timeago, time.timeago, time[datetime]").first() else {
            return nil
        }
        let datetime = try timeEl.attr("datetime")
        guard !datetime.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: datetime) { return date }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: datetime)
    }

    // MARK: - Helpers

    /// Extract the raw Craigslist post ID from a listing ID like "craigslist:sfbay:12345"
    private static func extractPostId(from listingId: String) -> String {
        let parts = listingId.split(separator: ":")
        return parts.count >= 3 ? String(parts[2]) : listingId
    }

    /// Extract post ID from a Craigslist URL
    private static func postIdFromURL(_ url: String) -> String {
        // URLs look like: https://sfbay.craigslist.org/sfc/ele/d/some-title/12345.html
        guard let lastComponent = url.split(separator: "/").last else {
            return url
        }
        return String(lastComponent).replacingOccurrences(of: ".html", with: "")
    }

    /// Remove price from title if present (e.g. "$500 - Icom IC-7300" -> "Icom IC-7300")
    private static func cleanTitle(_ title: String) -> String {
        var cleaned = title
        // Remove leading price patterns like "$500 -" or "$1,200 "
        if let range = cleaned.range(of: #"^\$[\d,]+(\.\d{2})?\s*[-–—]?\s*"#, options: .regularExpression) {
            cleaned = String(cleaned[range.upperBound...])
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    /// Keyword-based category inference from title and description
    private static func mapCategory(title: String, description: String) -> ListingCategory? {
        let text = (title + " " + description).lowercased()

        if text.contains("transceiver") || text.contains("rig ") || text.contains("radio") && !text.contains("antenna") && !text.contains("amplifier") {
            if text.contains("vhf") || text.contains("uhf") || text.contains("2m") || text.contains("70cm") || text.contains("handheld") || text.contains("ht ") {
                return .vhfUhfRadios
            }
            if text.contains("antique") || text.contains("vintage") || text.contains("tube") {
                return .antiqueRadios
            }
            return .hfRadios
        }
        if text.contains("antenna") || text.contains("yagi") || text.contains("dipole") || text.contains("vertical") || text.contains("beam") {
            return text.contains("vhf") || text.contains("uhf") ? .vhfUhfAntennas : .hfAntennas
        }
        if text.contains("amplifier") || text.contains("amp ") || text.contains("linear") {
            return text.contains("vhf") || text.contains("uhf") ? .vhfUhfAmplifiers : .hfAmplifiers
        }
        if text.contains("key") || text.contains("keyer") || text.contains("paddle") || text.contains("morse") || text.contains("cw ") {
            return .keys
        }
        if text.contains("tower") || text.contains("mast") || text.contains("crank-up") {
            return .towers
        }
        if text.contains("rotator") || text.contains("rotor") {
            return .rotators
        }
        if text.contains("test") || text.contains("meter") || text.contains("analyzer") || text.contains("oscilloscope") || text.contains("swr") {
            return .testEquipment
        }
        if text.contains("computer") || text.contains("raspberry") || text.contains("sdr") {
            return .computers
        }
        return nil
    }
}
