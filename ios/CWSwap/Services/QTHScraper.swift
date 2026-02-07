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

        // QTH uses <DL> definition lists: <DT> has title/status, <DD>s have description, metadata, actions
        let dtElements = try document.select("dl > dt")

        for dt in dtElements {
            // Title from <DT> > B > font or <DT> > B
            let titleElement = try dt.select("b font").first() ?? dt.select("b").first()
            guard let titleEl = titleElement else { continue }
            let rawTitle = try titleEl.text().trimmingCharacters(in: .whitespaces)
            if rawTitle.isEmpty { continue }

            // Extract listing ID from view_ad.php links in this DT or its sibling DDs
            var counterId: String?
            let dtLinks = try dt.select("a[href*=view_ad.php]")
            for link in dtLinks {
                let href = try link.attr("href")
                if let id = extractCounterId(from: href) {
                    counterId = id
                    break
                }
            }

            // Gather sibling DD elements after this DT
            var ddElements: [Element] = []
            var sibling = try dt.nextElementSibling()
            while let dd = sibling, dd.tagName() == "dd" {
                ddElements.append(dd)
                sibling = try dd.nextElementSibling()
            }

            // If no counter ID from DT, try DD links
            if counterId == nil {
                for dd in ddElements {
                    let links = try dd.select("a[href*=view_ad.php]")
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

            // First DD: description text
            let description: String
            if let firstDD = ddElements.first {
                description = try firstDD.text().trimmingCharacters(in: .whitespaces)
            } else {
                description = ""
            }

            // Second DD: metadata — callsign, date, listing info
            var callsign = ""
            var datePosted = Date()
            if ddElements.count > 1 {
                let metaDD = ddElements[1]
                // Callsign from link to callsign lookup
                if let callLink = try metaDD.select("a").first(where: { el in
                    let href = try el.attr("href")
                    return href.contains("callsign") || href.contains("qrz.com") || href.contains("qth.com")
                }) {
                    callsign = try callLink.text().trimmingCharacters(in: .whitespaces).uppercased()
                }
                // If no callsign link, try text pattern
                if callsign.isEmpty {
                    let metaText = try metaDD.text()
                    callsign = extractCallsign(from: metaText)
                }
                // Date from "Submitted on MM/DD/YY" or "MM/DD/YYYY"
                let metaText = try metaDD.text()
                datePosted = extractDate(from: metaText)
            }

            // Check for photo indicator (camera icon or photo link)
            var photoUrls: [String] = []
            let allText = try dt.html() + ddElements.map { try $0.html() }.joined()
            if allText.contains("camera") || allText.contains("photo") || allText.contains("image") {
                // Photo available — link to detail page serves as photo source
                photoUrls = ["https://swap.qth.com/view_ad.php?counter=\(id)"]
            }

            // Check for SOLD status
            let dtText = try dt.text().uppercased()
            let status: ListingStatus = dtText.contains("SOLD") ? .sold : .forSale

            // Extract price from description
            let price = PriceExtractor.extractPrice(from: description)

            // Extract contact info from description
            let contactInfo = ContactInfoExtractor.extractAll(from: description)

            // Infer category from title prefix
            let category = inferCategory(from: rawTitle)

            // Clean title (remove status prefixes like "FOR SALE:", "SOLD:", etc.)
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

    private static let callsignRegex = try! NSRegularExpression(
        pattern: #"\b([A-Z]{1,2}\d[A-Z0-9]*[A-Z])\b"#
    )

    private func extractCallsign(from text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = Self.callsignRegex.firstMatch(in: text.uppercased(), range: range),
              let matchRange = Range(match.range(at: 1), in: text.uppercased()) else {
            return ""
        }
        return String(text.uppercased()[matchRange])
    }

    private static let dateRegex = try! NSRegularExpression(
        pattern: #"(\d{1,2}/\d{1,2}/\d{2,4})"#
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
        // Try 4-digit year first, then 2-digit
        formatter.dateFormat = "M/d/yyyy"
        if let date = formatter.date(from: dateStr) { return date }
        formatter.dateFormat = "M/d/yy"
        return formatter.date(from: dateStr) ?? Date()
    }

    private func inferCategory(from title: String) -> ListingCategory? {
        let lowered = title.lowercased()
        if lowered.contains("antenna") { return ListingCategory.hfAntennas }
        if lowered.contains("amplifier") || lowered.contains("amp ") { return ListingCategory.hfAmplifiers }
        if lowered.contains("transceiver") || lowered.contains("radio") || lowered.contains("rig") { return ListingCategory.hfRadios }
        if lowered.contains("key") || lowered.contains("keyer") || lowered.contains("paddle") { return ListingCategory.keys }
        if lowered.contains("rotor") { return ListingCategory.rotators }
        if lowered.contains("tower") || lowered.contains("mast") { return ListingCategory.towers }
        if lowered.contains("meter") || lowered.contains("analyzer") || lowered.contains("dummy load") || lowered.contains("tuner") || lowered.contains("atu") { return ListingCategory.testEquipment }
        if lowered.contains("mic") || lowered.contains("microphone") || lowered.contains("headset") || lowered.contains("power supply") || lowered.contains("psu") { return ListingCategory.accessories }
        if lowered.contains("computer") || lowered.contains("interface") || lowered.contains("digital") { return ListingCategory.computers }
        if lowered.contains("antique") || lowered.contains("vintage") { return ListingCategory.antiqueRadios }
        return nil
    }

    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        let prefixes = ["FOR SALE:", "FOR SALE -", "SOLD:", "SOLD -", "FS:", "FS -", "WANTED:", "WTB:"]
        for prefix in prefixes {
            if cleaned.uppercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return cleaned
    }
}
