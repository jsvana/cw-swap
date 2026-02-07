import Foundation
import SwiftSoup

final class QTHScraper: Sendable {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Category Page

    func scrapeListingPage(page: Int) async throws -> [Listing] {
        let url = URL(string: "https://swap.qth.com/c_hamfest.php?page=\(page)")!
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode QTH listing page")
        }
        return try parseListingPage(html: html)
    }

    // MARK: - Detail Page

    func scrapeDetail(id: String) async throws -> Listing {
        let url = URL(string: "https://swap.qth.com/view_ad.php?counter=\(id)")!
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode QTH detail page")
        }
        return try parseDetailPage(html: html, id: id)
    }

    // MARK: - Full Page Scrape

    func scrapeFullPage(page: Int) async throws -> [Listing] {
        let summaries = try await scrapeListingPage(page: page)
        var listings: [Listing] = []

        for summary in summaries {
            // Extract the counter ID from the listing ID
            let counterId = summary.id.replacingOccurrences(of: "qth:", with: "")
            do {
                let detail = try await scrapeDetail(id: counterId)
                listings.append(detail)
            } catch {
                // Fall back to summary if detail fails
                listings.append(summary)
            }
            // Rate limit
            try await Task.sleep(for: .seconds(1))
        }

        return listings
    }

    // MARK: - Parsing

    private func parseListingPage(html: String) throws -> [Listing] {
        let document = try SwiftSoup.parse(html)
        var listings: [Listing] = []

        // QTH uses table rows for listings
        let rows = try document.select("table tr")

        for row in rows {
            let links = try row.select("a[href*=view_ad.php]")
            guard let link = links.first() else { continue }

            let href = try link.attr("href")
            guard let counterId = extractCounterId(from: href) else { continue }

            let title = try link.text().trimmingCharacters(in: .whitespaces)
            if title.isEmpty { continue }

            // Try to extract callsign and price from adjacent cells
            let cells = try row.select("td")
            let callsign = cells.count > 1 ? (try? cells[1].text().trimmingCharacters(in: .whitespaces)) ?? "" : ""

            let fullText = try row.text()
            let price = PriceExtractor.extractPrice(from: fullText)

            listings.append(Listing(
                id: "qth:\(counterId)",
                source: .qth,
                sourceUrl: "https://swap.qth.com/view_ad.php?counter=\(counterId)",
                title: title,
                description: "",
                descriptionHtml: "",
                status: .forSale,
                callsign: callsign,
                memberId: nil,
                avatarUrl: nil,
                price: price,
                photoUrls: [],
                category: nil,
                datePosted: Date(),
                dateModified: nil,
                replies: 0,
                views: 0
            ))
        }

        return listings
    }

    private func parseDetailPage(html: String, id: String) throws -> Listing {
        let document = try SwiftSoup.parse(html)

        // Title - usually in a heading or bold element
        let title = try document.select("h2, h3, b").first()?.text()
            .trimmingCharacters(in: .whitespaces) ?? "Untitled"

        // Description from main content area
        let bodyText = try document.body()?.text() ?? ""

        // Extract callsign — look for "by CALLSIGN" pattern
        let callsignRegex = try! NSRegularExpression(pattern: #"by\s+([A-Z0-9]{3,10})\b"#)
        let callsign: String
        let nsBody = bodyText as NSString
        if let match = callsignRegex.firstMatch(in: bodyText, range: NSRange(location: 0, length: nsBody.length)),
           let range = Range(match.range(at: 1), in: bodyText) {
            callsign = String(bodyText[range])
        } else {
            callsign = ""
        }

        // Extract date — "Submitted on MM/DD/YYYY" pattern
        let dateRegex = try! NSRegularExpression(pattern: #"Submitted on\s+(\d{1,2}/\d{1,2}/\d{4})"#)
        let datePosted: Date
        if let match = dateRegex.firstMatch(in: bodyText, range: NSRange(location: 0, length: nsBody.length)),
           let range = Range(match.range(at: 1), in: bodyText) {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yyyy"
            datePosted = formatter.date(from: String(bodyText[range])) ?? Date()
        } else {
            datePosted = Date()
        }

        // Photos — image tags in the content
        var photoUrls: [String] = []
        let images = try document.select("img[src]")
        for img in images {
            let src = try img.attr("src")
            if src.contains("swap.qth.com") || src.contains("qth.com/images/") {
                let resolved = src.hasPrefix("http") ? src : "https://swap.qth.com/\(src)"
                photoUrls.append(resolved)
            }
        }

        // Price from body text
        let price = PriceExtractor.extractPrice(from: bodyText)

        // Status — check for "SOLD" in the page
        let status: ListingStatus = bodyText.localizedCaseInsensitiveContains("SOLD") ? .sold : .forSale

        return Listing(
            id: "qth:\(id)",
            source: .qth,
            sourceUrl: "https://swap.qth.com/view_ad.php?counter=\(id)",
            title: title,
            description: bodyText.prefix(2000).trimmingCharacters(in: .whitespaces),
            descriptionHtml: "",
            status: status,
            callsign: callsign,
            memberId: nil,
            avatarUrl: nil,
            price: price,
            photoUrls: photoUrls,
            category: nil,
            datePosted: datePosted,
            dateModified: nil,
            replies: 0,
            views: 0
        )
    }

    // MARK: - Helpers

    private func extractCounterId(from href: String) -> String? {
        guard let range = href.range(of: "counter=") else { return nil }
        let id = String(href[range.upperBound...]).trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
        return id.isEmpty ? nil : id
    }
}
