import Foundation
import SwiftSoup

final class HamEstateScraper: Sendable {
    private static let baseURL = "https://www.hamestate.com"
    private static let categoryPath = "/product-category/ham_equipment"

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Full Page Scrape

    func scrapeFullPage(page: Int) async throws -> [Listing] {
        let url: URL
        if page <= 1 {
            url = URL(string: "\(Self.baseURL)\(Self.categoryPath)/")!
        } else {
            url = URL(string: "\(Self.baseURL)\(Self.categoryPath)/page/\(page)/")!
        }

        let request = Self.makeRequest(url: url)
        let (data, response) = try await session.data(for: request)

        // Page beyond last returns 404 in WooCommerce
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return []
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode HamEstate listing page")
        }

        return try parseListingPage(html: html)
    }

    /// Progressive scraping: fetches listing page, then each product detail page.
    func scrapeFullPage(
        page: Int,
        onListing: (Listing) -> Void,
        onProgress: (Int, Int) -> Void
    ) async throws {
        let url: URL
        if page <= 1 {
            url = URL(string: "\(Self.baseURL)\(Self.categoryPath)/")!
        } else {
            url = URL(string: "\(Self.baseURL)\(Self.categoryPath)/page/\(page)/")!
        }

        let request = Self.makeRequest(url: url)
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            onProgress(0, 0)
            return
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode HamEstate listing page")
        }

        let stubs = try parseProductStubs(html: html)
        let total = stubs.count
        var completed = 0

        onProgress(0, total)

        for stub in stubs {
            do {
                let listing = try await scrapeProductDetail(stub: stub)
                onListing(listing)
            } catch {
                // Fall back to stub-only listing if detail fails
                onListing(stub.toListing())
            }
            completed += 1
            onProgress(completed, total)
            // Rate limit: respect the server
            try await Task.sleep(for: .seconds(1))
        }
    }

    // MARK: - Product Detail

    private func scrapeProductDetail(stub: ProductStub) async throws -> Listing {
        let request = Self.makeRequest(url: URL(string: stub.url)!)
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode HamEstate product page")
        }
        return try parseProductDetail(html: html, stub: stub)
    }

    // MARK: - Listing Page Parsing

    /// Intermediate struct for data extracted from the category listing page.
    private struct ProductStub: Sendable {
        let id: String
        let url: String
        let title: String
        let price: Price?
        let thumbnailUrl: String?
        let isSold: Bool

        func toListing() -> Listing {
            Listing(
                id: "hamestate:\(id)",
                source: .hamestate,
                sourceUrl: url,
                title: title,
                description: "",
                descriptionHtml: "",
                status: isSold ? .sold : .forSale,
                callsign: "",
                memberId: nil,
                avatarUrl: nil,
                price: price,
                photoUrls: thumbnailUrl.map { [$0] } ?? [],
                category: nil,
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

    private func parseListingPage(html: String) throws -> [Listing] {
        let stubs = try parseProductStubs(html: html)
        return stubs.map { $0.toListing() }
    }

    private func parseProductStubs(html: String) throws -> [ProductStub] {
        let document = try SwiftSoup.parse(html)
        var stubs: [ProductStub] = []

        // WooCommerce standard: ul.products li.product or just li.product
        let productElements = try document.select("li.product")

        for element in productElements {
            // Extract product ID from CSS classes: "post-123" pattern
            let classes = try element.attr("class")
            let productId = Self.extractProductId(from: classes)
            guard let id = productId else { continue }

            // Product link and title
            // WooCommerce: a.woocommerce-LoopProduct-link > h2.woocommerce-loop-product__title
            // Fallback: first a[href] containing /product/
            let linkEl = try element.select("a.woocommerce-LoopProduct-link").first()
                ?? element.select("a[href*=/product/]").first()
            guard let link = linkEl else { continue }

            let productUrl = try link.attr("href")
            guard !productUrl.isEmpty else { continue }

            // Title
            let title: String
            if let titleEl = try element.select(".woocommerce-loop-product__title").first()
                ?? element.select("h2").first() {
                title = try titleEl.text().trimmingCharacters(in: .whitespaces)
            } else {
                title = try link.text().trimmingCharacters(in: .whitespaces)
            }
            if title.isEmpty { continue }

            // Thumbnail image
            let thumbnailUrl: String?
            if let imgEl = try element.select("img").first() {
                // Prefer data-src (lazy-loaded) or src
                let dataSrc = try imgEl.attr("data-src")
                let src = try imgEl.attr("src")
                let rawUrl = dataSrc.isEmpty ? src : dataSrc
                thumbnailUrl = rawUrl.isEmpty ? nil : Self.resolveURL(rawUrl)
            } else {
                thumbnailUrl = nil
            }

            // Price from WooCommerce price markup
            let price = try Self.extractWooCommercePrice(from: element)

            // Out of stock / sold
            let isSold = classes.contains("outofstock")

            stubs.append(ProductStub(
                id: id,
                url: Self.resolveURL(productUrl),
                title: Self.cleanTitle(title),
                price: price,
                thumbnailUrl: thumbnailUrl,
                isSold: isSold
            ))
        }

        return stubs
    }

    // MARK: - Product Detail Parsing

    private func parseProductDetail(html: String, stub: ProductStub) throws -> Listing {
        let document = try SwiftSoup.parse(html)

        // Title: prefer h1.product_title
        let title: String
        if let titleEl = try document.select("h1.product_title").first()
            ?? document.select(".product_title").first() {
            title = Self.cleanTitle(try titleEl.text().trimmingCharacters(in: .whitespaces))
        } else {
            title = stub.title
        }

        // Price: from detail page or fall back to stub
        let price: Price?
        if let priceEl = try document.select("p.price").first()
            ?? document.select(".summary .price").first() {
            price = try Self.extractWooCommercePrice(from: priceEl)
        } else {
            price = stub.price
        }

        // Short description
        let shortDesc = try document.select(".woocommerce-product-details__short-description").first()?
            .text().trimmingCharacters(in: .whitespaces) ?? ""

        // Full description from tabs
        let fullDesc = try document.select("#tab-description").first()?
            .text().trimmingCharacters(in: .whitespaces)
            ?? (try document.select(".woocommerce-Tabs-panel--description").first()?
                .text().trimmingCharacters(in: .whitespaces) ?? "")

        // Use the longer description
        let description = fullDesc.count > shortDesc.count ? fullDesc : shortDesc

        // Description HTML (short description)
        let descriptionHtml = try document.select(".woocommerce-product-details__short-description").first()?
            .html() ?? ""

        // Gallery images
        var photoUrls: [String] = []

        // WooCommerce gallery: .woocommerce-product-gallery__image
        let galleryImages = try document.select(".woocommerce-product-gallery__image img, .woocommerce-product-gallery img")
        for img in galleryImages {
            // Prefer full-size: data-large_image, data-src, or src
            let largeSrc = try img.attr("data-large_image")
            let dataSrc = try img.attr("data-src")
            let src = try img.attr("src")
            let imageUrl = !largeSrc.isEmpty ? largeSrc
                : !dataSrc.isEmpty ? dataSrc : src

            if !imageUrl.isEmpty {
                let resolved = Self.resolveURL(imageUrl)
                // Skip placeholder images
                if !resolved.contains("placeholder") && !photoUrls.contains(resolved) {
                    photoUrls.append(resolved)
                }
            }
        }

        // Fallback: og:image meta tag
        if photoUrls.isEmpty {
            if let ogImage = try document.select("meta[property=og:image]").first() {
                let content = try ogImage.attr("content")
                if !content.isEmpty {
                    photoUrls.append(Self.resolveURL(content))
                }
            }
        }

        // Fallback to thumbnail from stub
        if photoUrls.isEmpty, let thumb = stub.thumbnailUrl {
            photoUrls.append(thumb)
        }

        // Status: check for out of stock
        let status: ListingStatus
        let bodyClasses = try document.select("body").first()?.attr("class") ?? ""
        if bodyClasses.contains("outofstock") || stub.isSold {
            status = .sold
        } else {
            status = .forSale
        }

        // Category from WooCommerce product meta
        let category = try Self.extractCategory(from: document)

        // Contact info from description
        let fullText = "\(shortDesc) \(fullDesc)"
        let contactInfo = ContactInfoExtractor.extractAll(from: fullText)

        // Date: try to extract from structured data or fall back to now
        let datePosted = Self.extractDate(from: document)

        return Listing(
            id: "hamestate:\(stub.id)",
            source: .hamestate,
            sourceUrl: stub.url,
            title: title,
            description: description,
            descriptionHtml: descriptionHtml,
            status: status,
            callsign: "",
            memberId: nil,
            avatarUrl: nil,
            price: price,
            photoUrls: photoUrls,
            category: category,
            datePosted: datePosted,
            dateModified: nil,
            replies: 0,
            views: 0,
            contactEmail: contactInfo.email,
            contactPhone: contactInfo.phone,
            contactMethods: contactInfo.methods
        )
    }

    // MARK: - Helpers

    private static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        return request
    }

    private static let postIdRegex = try! NSRegularExpression(pattern: #"\bpost-(\d+)\b"#)

    private static func extractProductId(from classes: String) -> String? {
        let range = NSRange(classes.startIndex..., in: classes)
        guard let match = postIdRegex.firstMatch(in: classes, range: range),
              let idRange = Range(match.range(at: 1), in: classes) else {
            return nil
        }
        let id = String(classes[idRange])
        return id.isEmpty ? nil : id
    }

    private static func extractWooCommercePrice(from element: Element) throws -> Price? {
        // WooCommerce price structure:
        // <span class="price">
        //   <del><span class="woocommerce-Price-amount">$100.00</span></del>  (original)
        //   <ins><span class="woocommerce-Price-amount">$80.00</span></ins>   (sale)
        // or just:
        //   <span class="woocommerce-Price-amount">$100.00</span>

        // Try sale price first (inside <ins>)
        if let insEl = try element.select("ins .woocommerce-Price-amount").first()
            ?? element.select("ins .amount").first() {
            let text = try insEl.text()
            if let price = parseWooPrice(text) { return price }
        }

        // Regular price (first .woocommerce-Price-amount not inside <del>)
        let priceEls = try element.select(".woocommerce-Price-amount, .amount")
        for priceEl in priceEls {
            // Skip if inside <del> (original/crossed-out price)
            let parent = priceEl.parent()
            if let parentTag = parent?.tagName(), parentTag == "del" { continue }
            // Also skip if grandparent is del
            if let grandparent = parent?.parent(), grandparent.tagName() == "del" { continue }

            let text = try priceEl.text()
            if let price = parseWooPrice(text) { return price }
        }

        // Fallback: try PriceExtractor on the price element text
        let priceText = try element.select(".price").first()?.text() ?? ""
        return PriceExtractor.extractPrice(from: priceText)
    }

    private static func parseWooPrice(_ text: String) -> Price? {
        // WooCommerce formats prices as "$1,234.56" or "1,234.56"
        let cleaned = text.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: "")
        guard let amount = Double(cleaned), amount >= 0.01, amount <= 500_000 else {
            return nil
        }
        return Price(amount: amount, currency: "USD", includesShipping: false, obo: false)
    }

    /// Extract category from WooCommerce product_cat terms.
    private static func extractCategory(from document: Document) throws -> ListingCategory? {
        // WooCommerce adds product_cat classes to body or product container
        let bodyClasses = try document.select("body").first()?.attr("class") ?? ""

        // Also check .posted_in links (product meta)
        let categoryLinks = try document.select(".posted_in a, .product_meta a[rel=tag]")
        let categoryTexts = try categoryLinks.map { try $0.text().lowercased() }

        // Also extract from body classes: "product_cat-<slug>" pattern
        let catSlugs = bodyClasses.components(separatedBy: .whitespaces)
            .filter { $0.hasPrefix("product_cat-") }
            .map { String($0.dropFirst("product_cat-".count)).lowercased() }

        let allCats = categoryTexts + catSlugs

        for cat in allCats {
            if let mapped = mapCategory(cat) { return mapped }
        }
        return nil
    }

    private static func mapCategory(_ text: String) -> ListingCategory? {
        let t = text.lowercased()
        // HF radios
        if t.contains("hf") && (t.contains("radio") || t.contains("transceiver") || t.contains("rig")) {
            return .hfRadios
        }
        // VHF/UHF radios
        if (t.contains("vhf") || t.contains("uhf") || t.contains("handheld") || t.contains("ht")) &&
            (t.contains("radio") || t.contains("transceiver")) {
            return .vhfUhfRadios
        }
        // Amplifiers
        if t.contains("amplifier") || t.contains("amp") {
            if t.contains("vhf") || t.contains("uhf") { return .vhfUhfAmplifiers }
            return .hfAmplifiers
        }
        // Antennas
        if t.contains("antenna") || t.contains("beam") || t.contains("yagi") || t.contains("dipole") {
            if t.contains("vhf") || t.contains("uhf") { return .vhfUhfAntennas }
            return .hfAntennas
        }
        // Towers
        if t.contains("tower") || t.contains("mast") { return .towers }
        // Rotators
        if t.contains("rotator") || t.contains("rotor") { return .rotators }
        // Keys
        if t.contains("key") || t.contains("keyer") || t.contains("paddle") { return .keys }
        // Test equipment
        if t.contains("test") || t.contains("analyzer") || t.contains("meter") || t.contains("oscilloscope") {
            return .testEquipment
        }
        // Computers
        if t.contains("computer") || t.contains("laptop") || t.contains("pc") { return .computers }
        // Antique
        if t.contains("antique") || t.contains("vintage") || t.contains("classic") { return .antiqueRadios }
        // Accessories
        if t.contains("accessori") || t.contains("cable") || t.contains("power supply") || t.contains("mic") {
            return .accessories
        }
        // Misc
        if t.contains("misc") || t.contains("other") { return .miscellaneous }
        return nil
    }

    /// Try to extract a publish date from JSON-LD structured data or og:article:published_time.
    private static func extractDate(from document: Document) -> Date {
        // Try JSON-LD
        if let scriptEl = try? document.select("script[type=application/ld+json]") {
            for script in scriptEl {
                let json = (try? script.data()) ?? ""
                if let data = json.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dateStr = obj["datePublished"] as? String ?? obj["dateCreated"] as? String {
                    if let date = parseISO8601(dateStr) { return date }
                }
            }
        }

        // Try og:article:published_time or article:published_time
        if let meta = try? document.select("meta[property=article:published_time]").first()
            ?? document.select("meta[property=og:updated_time]").first() {
            let content = (try? meta.attr("content")) ?? ""
            if let date = parseISO8601(content) { return date }
        }

        // Try <time> element with datetime attribute
        if let timeEl = try? document.select("time[datetime]").first() {
            let datetime = (try? timeEl.attr("datetime")) ?? ""
            if let date = parseISO8601(datetime) { return date }
        }

        return Date()
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func resolveURL(_ url: String) -> String {
        if url.hasPrefix("http") { return url }
        if url.hasPrefix("//") { return "https:\(url)" }
        return "\(baseURL)/\(url.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
    }

    private static func cleanTitle(_ title: String) -> String {
        var cleaned = title
        // Strip common prefixes like "SOLD –", "SOLD:", etc.
        let prefixes = ["SOLD –", "SOLD -", "SOLD:", "SOLD", "FOR SALE:", "FOR SALE -", "FS:", "FS -"]
        for prefix in prefixes {
            if cleaned.uppercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        // WooCommerce sometimes HTML-encodes entities
        cleaned = cleaned
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
        return cleaned
    }
}
