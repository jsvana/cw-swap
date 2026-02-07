import Foundation
import SwiftSoup

final class QTHScraper: Sendable {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Listing Page

    func scrapeFullPage(page: Int) async throws -> [Listing] {
        let url = URL(string: "https://swap.qth.com/all.php?perpage=10&sort=date&page=\(page)")!
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode QTH listing page")
        }
        return try parseListingPage(html: html)
    }

    // MARK: - Parsing

    private func parseListingPage(html: String) throws -> [Listing] {
        let document = try SwiftSoup.parse(html)
        var listings: [Listing] = []

        // QTH uses a single <DL> with <DT> for each listing header, followed by <DD>s
        let dtElements = try document.select("dt")

        for dt in dtElements {
            // Each DT contains: icon, <B><font color=0000FF>CATEGORY</font><font> - TITLE</font></B>, optional camera link
            guard let boldEl = try dt.select("b").first() else { continue }
            let fontElements = try boldEl.select("font")
            guard fontElements.size() >= 2 else { continue }

            // First font = category code (e.g., "AMPHF", "RADIOHF", "TEST")
            let categoryCode = try fontElements.get(0).text().trimmingCharacters(in: .whitespaces)

            // Second font = title with leading " - "
            let rawTitle = try fontElements.get(1).text()
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "^\\s*-\\s*", with: "", options: .regularExpression)
            if rawTitle.isEmpty { continue }

            // Extract listing ID from view_ad.php camera link in the DT
            var counterId: String?
            let dtLinks = try dt.select("a[href*=view_ad.php]")
            for link in dtLinks {
                if let id = extractCounterId(from: try link.attr("href")) {
                    counterId = id
                    break
                }
            }

            // Gather sibling DD elements after this DT
            var ddElements: [Element] = []
            var sibling = try dt.nextElementSibling()
            while let dd = sibling, dd.tagName().lowercased() == "dd" {
                ddElements.append(dd)
                sibling = try dd.nextElementSibling()
            }

            // If no counter ID from DT camera link, try DD links
            if counterId == nil {
                for dd in ddElements {
                    let links = try dd.select("a[href*=view_ad.php]")
                    for link in links {
                        if let id = extractCounterId(from: try link.attr("href")) {
                            counterId = id
                            break
                        }
                    }
                    if counterId != nil { break }
                }
            }

            // Also check contact.php links for listing ID
            if counterId == nil {
                for dd in ddElements {
                    let links = try dd.select("a[href*=contact.php]")
                    for link in links {
                        let href = try link.attr("href")
                        if let id = extractCounterId(from: href) {
                            counterId = id
                            break
                        }
                    }
                    if counterId != nil { break }
                }
            }

            guard let id = counterId else { continue }

            // First DD: description text (inside <font> tag)
            let description: String
            if let firstDD = ddElements.first {
                description = try firstDD.text().trimmingCharacters(in: .whitespaces)
            } else {
                description = ""
            }

            // Second DD: metadata — "Listing #ID - Submitted on DATE by Callsign <a>CALL</a>..."
            var callsign = ""
            var datePosted = Date()
            if ddElements.count > 1 {
                let metaDD = ddElements[1]
                let metaText = try metaDD.text()

                // Callsign from link to qth.com/callsign.php
                if let callLink = try metaDD.select("a[href*=callsign]").first() {
                    callsign = try callLink.text().trimmingCharacters(in: .whitespaces).uppercased()
                }

                // Date from "Submitted on MM/DD/YY"
                datePosted = extractDate(from: metaText)
            }

            // Photo: if there's a camera_icon link in the DT, photo is available
            // QTH stores images at segamida/<counter>.jpg (deterministic URL)
            let hasPhoto = !dtLinks.isEmpty()
            let photoUrls: [String] = hasPhoto
                ? ["https://swap.qth.com/segamida/\(id).jpg"]
                : []

            // Status: check DT text for SOLD
            let dtText = try dt.text().uppercased()
            let status: ListingStatus = dtText.contains("SOLD") ? .sold : .forSale

            // Price from description
            let price = PriceExtractor.extractPrice(from: description)

            // Contact info from description
            let contactInfo = ContactInfoExtractor.extractAll(from: description)

            // Map QTH category codes to our categories
            let category = mapCategory(code: categoryCode)

            // Clean title (strip "FOR SALE:", etc.)
            let title = cleanTitle(rawTitle)

            listings.append(Listing(
                id: "qth:\(id)",
                source: .qth,
                sourceUrl: "https://swap.qth.com/view_ad.php?counter=\(id)",
                title: title,
                description: description,
                descriptionHtml: "",
                status: status,
                callsign: callsign,
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
            ))
        }

        return listings
    }

    // MARK: - Helpers

    private func extractCounterId(from href: String) -> String? {
        guard let range = href.range(of: "counter=") else { return nil }
        let id = String(href[range.upperBound...]).trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
        return id.isEmpty ? nil : id
    }

    private static let dateRegex = try! NSRegularExpression(
        pattern: #"Submitted on\s+(\d{1,2}/\d{1,2}/\d{2,4})"#
    )

    private func extractDate(from text: String) -> Date {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = Self.dateRegex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range(at: 1), in: text) else {
            return Date()
        }
        let dateStr = String(text[matchRange])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try 2-digit year first — yyyy leniently accepts "26" as year 0026 AD
        formatter.dateFormat = "M/d/yy"
        if let date = formatter.date(from: dateStr) { return date }
        formatter.dateFormat = "M/d/yyyy"
        return formatter.date(from: dateStr) ?? Date()
    }

    /// Map QTH category codes to ListingCategory.
    /// Codes seen in HTML: AMPHF, AMPVHF, ANTHF, ANTVHF, RADIOHF, RADIOVHF,
    /// TOWER, ROTOR, KEY, TEST, COMP, ANTIQUE, ACCESS, MISC
    private func mapCategory(code: String) -> ListingCategory? {
        switch code.uppercased() {
        case "RADIOHF": return .hfRadios
        case "RADIOVHF": return .vhfUhfRadios
        case "AMPHF": return .hfAmplifiers
        case "AMPVHF": return .vhfUhfAmplifiers
        case "ANTHF": return .hfAntennas
        case "ANTVHF": return .vhfUhfAntennas
        case "TOWER": return .towers
        case "ROTOR": return .rotators
        case "KEY": return .keys
        case "TEST": return .testEquipment
        case "COMP": return .computers
        case "ANTIQUE": return .antiqueRadios
        case "ACCESS": return .accessories
        case "MISC": return .miscellaneous
        default: return nil
        }
    }

    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        let prefixes = ["FOR SALE:", "FOR SALE -", "SOLD:", "SOLD -", "FS:", "FS -", "WANTED:", "WTB:", "FOR SALE/TRADE"]
        for prefix in prefixes {
            if cleaned.uppercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return cleaned
    }
}
