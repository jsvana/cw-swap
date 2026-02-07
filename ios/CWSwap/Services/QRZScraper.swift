import Foundation
import SwiftSoup

enum ScraperError: Error, LocalizedError {
    case loginFailed(String)
    case parseFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .loginFailed(let msg): "Login failed: \(msg)"
        case .parseFailed(let msg): "Parse error: \(msg)"
        case .networkError(let err): "Network error: \(err.localizedDescription)"
        }
    }
}

struct ThreadEntry: Sendable {
    let threadId: Int64
    let title: String
    let url: String
    let replies: Int
    let views: Int
    let isSticky: Bool
}

final class QRZScraper: Sendable {
    private static let qrzBase = "https://forums.qrz.com/index.php"

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        if let store = HTTPCookieStorage.shared as HTTPCookieStorage? {
            config.httpCookieStorage = store
        }
        self.session = URLSession(configuration: config)
    }

    // MARK: - Login

    func login(username: String, password: String) async throws {
        // Step 1: GET main QRZ login page to extract CSRF token
        let loginURL = URL(string: "https://www.qrz.com/login")!
        let (loginData, _) = try await session.data(from: loginURL)
        let loginPage = String(data: loginData, encoding: .utf8) ?? ""

        let token = extractHiddenInput(html: loginPage, name: "_token")
            ?? extractHiddenInput(html: loginPage, name: "_xfToken")

        // Step 2: POST login to main QRZ site
        var loginRequest = URLRequest(url: loginURL)
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var formParts = [
            "username=\(urlEncode(username))",
            "password=\(urlEncode(password))",
        ]
        if let token {
            formParts.append("_token=\(urlEncode(token))")
        }
        loginRequest.httpBody = formParts.joined(separator: "&").data(using: .utf8)

        let (responseData, _) = try await session.data(for: loginRequest)
        let responseBody = String(data: responseData, encoding: .utf8) ?? ""

        if responseBody.contains("Incorrect password")
            || responseBody.contains("Invalid credentials")
            || responseBody.contains("These credentials do not match") {
            throw ScraperError.loginFailed("Incorrect username or password")
        }

        // Step 3: Also log into XenForo forums
        let forumsLoginURL = URL(string: "\(Self.qrzBase)?login/")!
        let (forumsData, _) = try await session.data(from: forumsLoginURL)
        let forumsPage = String(data: forumsData, encoding: .utf8) ?? ""

        if let xfToken = extractHiddenInput(html: forumsPage, name: "_xfToken") {
            var forumsRequest = URLRequest(url: URL(string: "\(Self.qrzBase)?login/login")!)
            forumsRequest.httpMethod = "POST"
            forumsRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let forumsForm = [
                "login=\(urlEncode(username))",
                "password=\(urlEncode(password))",
                "_xfToken=\(urlEncode(xfToken))",
                "remember=1",
            ].joined(separator: "&")
            forumsRequest.httpBody = forumsForm.data(using: .utf8)

            _ = try await session.data(for: forumsRequest)
        }
    }

    // MARK: - Listing Page

    func scrapeListingPage(page: Int) async throws -> [ThreadEntry] {
        let url = URL(string: "\(Self.qrzBase)?forums/ham-radio-gear-for-sale.7/page-\(page)")!
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode listing page HTML")
        }
        return try parseListingPage(html: html)
    }

    // MARK: - Thread Detail

    func scrapeThread(threadId: Int64, slug: String) async throws -> Listing {
        let url = "\(Self.qrzBase)?threads/\(slug).\(threadId)/"
        let (data, _) = try await session.data(from: URL(string: url)!)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode thread HTML")
        }
        return try parseThreadDetail(html: html, threadId: threadId, sourceUrl: url)
    }

    // MARK: - Full Page Scrape

    func scrapeFullPage(page: Int) async throws -> [Listing] {
        let entries = try await scrapeListingPage(page: page)
        var listings: [Listing] = []

        for entry in entries where !entry.isSticky {
            let slug = Self.slugFromURL(entry.url)
            do {
                var listing = try await scrapeThread(threadId: entry.threadId, slug: slug)
                listing = Listing(
                    id: listing.id,
                    source: listing.source,
                    sourceUrl: listing.sourceUrl,
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
                    replies: entry.replies,
                    views: entry.views
                )
                listings.append(listing)
            } catch {
                // Skip failed threads, continue with others
                continue
            }
            // Rate limit: 1 request per second
            try await Task.sleep(for: .seconds(1))
        }

        return listings
    }

    // MARK: - Parsing

    private func parseListingPage(html: String) throws -> [ThreadEntry] {
        let document = try SwiftSoup.parse(html)
        let threadElements = try document.select("li.discussionListItem")

        var entries: [ThreadEntry] = []

        for element in threadElements {
            guard let idAttr = try? element.attr("id"),
                  idAttr.hasPrefix("thread-"),
                  let threadId = Int64(idAttr.replacingOccurrences(of: "thread-", with: "")),
                  threadId > 0 else {
                continue
            }

            // Title and URL from PreviewTooltip link
            let titleLink = try element.select("h3.title a.PreviewTooltip").first()
                ?? element.select("h3.title a[href*=threads/]").first()

            guard let titleEl = titleLink else { continue }

            let title = try titleEl.text().trimmingCharacters(in: .whitespaces)
            let url = try titleEl.attr("href")

            // Replies from dl.major dd
            let replies = try element.select("dl.major dd").first()
                .map { try $0.text().replacingOccurrences(of: ",", with: "") }
                .flatMap { Int($0) } ?? 0

            // Views from dl.minor dd
            let views = try element.select("dl.minor dd").first()
                .map { try $0.text().replacingOccurrences(of: ",", with: "") }
                .flatMap { Int($0) } ?? 0

            let isSticky = (try? element.attr("class"))?.contains("sticky") ?? false

            entries.append(ThreadEntry(
                threadId: threadId,
                title: title,
                url: url,
                replies: replies,
                views: views,
                isSticky: isSticky
            ))
        }

        return entries
    }

    private func parseThreadDetail(html: String, threadId: Int64, sourceUrl: String) throws -> Listing {
        let document = try SwiftSoup.parse(html)

        // Parse title from h1
        guard let h1 = try document.select("h1").first() else {
            throw ScraperError.parseFailed("No h1 found")
        }
        let fullTitle = try h1.text().trimmingCharacters(in: .whitespaces)

        // Parse prefix/status
        let prefixText = try document.select("h1 span.prefix").first().map { try $0.text().trimmingCharacters(in: .whitespaces) }

        let status: ListingStatus = switch prefixText {
        case "SOLD": .sold
        case "Canceled": .canceled
        case "For Sale or Trade": .forSaleOrTrade
        default: .forSale
        }

        // Strip prefix from title
        let title: String
        if let prefix = prefixText, fullTitle.hasPrefix(prefix) {
            title = String(fullTitle.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "^\\s*-\\s*", with: "", options: .regularExpression)
        } else {
            title = fullTitle
        }

        // First message is the listing content
        guard let firstMsg = try document.select("li.message").first() else {
            throw ScraperError.parseFailed("No messages found")
        }

        let callsign = (try? firstMsg.attr("data-author")) ?? ""

        // Description
        let descriptionHtml = try firstMsg.select("blockquote.messageText").first()?.html() ?? ""
        let description = try firstMsg.select("blockquote.messageText").first()?.text()
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Avatar URL
        let avatarUrl = try firstMsg.select("div.messageUserBlock img").first()
            .flatMap { try? $0.attr("src") }
            .map { Self.resolveURL($0) }

        // Photos: prefer full-size from LbTrigger href
        var photoUrls: [String] = try firstMsg.select("a.LbTrigger").compactMap { el in
            let href = try el.attr("href")
            return href.isEmpty ? nil : Self.resolveURL(href)
        }

        if photoUrls.isEmpty {
            photoUrls = try firstMsg.select("img.bbCodeImage").compactMap { el in
                let src = try el.attr("src")
                return src.isEmpty ? nil : Self.resolveURL(src)
            }
        }

        // Post date from first message
        let datePosted: Date
        if let dateEl = try firstMsg.select("abbr.DateTime[data-time]").first(),
           let timestamp = Int64(try dateEl.attr("data-time")) {
            datePosted = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            datePosted = Date()
        }

        // Last edited date
        let dateModified: Date?
        if let editEl = try firstMsg.select("div.editDate abbr.DateTime[data-time]").first(),
           let timestamp = Int64(try editEl.attr("data-time")) {
            dateModified = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            dateModified = nil
        }

        // Member ID from member link
        let memberId: Int?
        if let memberLink = try firstMsg.select("a[href*=members/]").first() {
            let href = try memberLink.attr("href")
            memberId = href.split(separator: ".").last
                .flatMap { Int(String($0).trimmingCharacters(in: CharacterSet(charactersIn: "/"))) }
        } else {
            memberId = nil
        }

        // Extract price from description
        let price = PriceExtractor.extractPrice(from: description)

        return Listing(
            id: "qrz:\(threadId)",
            source: .qrz,
            sourceUrl: sourceUrl,
            title: title,
            description: description,
            descriptionHtml: descriptionHtml,
            status: status,
            callsign: callsign,
            memberId: memberId,
            avatarUrl: avatarUrl,
            price: price,
            photoUrls: photoUrls,
            category: nil,
            datePosted: datePosted,
            dateModified: dateModified,
            replies: 0,
            views: 0
        )
    }

    // MARK: - Helpers

    private static func slugFromURL(_ url: String) -> String {
        guard let threadsPart = url.split(separator: "threads/").last else { return "" }
        let str = String(threadsPart)
        guard let dotPos = str.lastIndex(of: ".") else { return "" }
        return String(str[str.startIndex..<dotPos])
    }

    private static func resolveURL(_ url: String) -> String {
        if url.hasPrefix("http") { return url }
        return "https://forums.qrz.com/\(url.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
    }

    private func extractHiddenInput(html: String, name: String) -> String? {
        guard let document = try? SwiftSoup.parse(html),
              let input = try? document.select("input[name=\(name)][type=hidden]").first(),
              let value = try? input.attr("value") else {
            return nil
        }
        return value.isEmpty ? nil : value
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
