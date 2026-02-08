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
        var listings: [Listing] = []
        try await scrapeFullPage(
            page: page,
            onListing: { listing in listings.append(listing) },
            onProgress: { _, _ in }
        )
        return listings
    }

    /// Scrapes thread details concurrently (up to 5 at a time) for progress tracking.
    func scrapeFullPage(
        page: Int,
        onListing: (Listing) -> Void,
        onProgress: (Int, Int) -> Void
    ) async throws {
        let entries = try await scrapeListingPage(page: page)
        let nonSticky = entries.filter { !$0.isSticky }
        let total = nonSticky.count
        var completed = 0
        let maxConcurrency = 5

        onProgress(0, total)

        await withTaskGroup(of: Listing?.self) { group in
            var nextIndex = 0

            // Seed initial batch
            while nextIndex < min(maxConcurrency, nonSticky.count) {
                let entry = nonSticky[nextIndex]
                nextIndex += 1
                group.addTask { await self.scrapeEntry(entry) }
            }

            // Process results as they arrive, enqueue more work
            for await listing in group {
                completed += 1
                onProgress(completed, total)
                if let listing {
                    onListing(listing)
                }

                if nextIndex < nonSticky.count {
                    let entry = nonSticky[nextIndex]
                    nextIndex += 1
                    group.addTask { await self.scrapeEntry(entry) }
                }
            }
        }
    }

    private func scrapeEntry(_ entry: ThreadEntry) async -> Listing? {
        let slug = Self.slugFromURL(entry.url)
        do {
            let listing = try await scrapeThread(threadId: entry.threadId, slug: slug)
            return Listing(
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
                views: entry.views,
                contactEmail: listing.contactEmail,
                contactPhone: listing.contactPhone,
                contactMethods: listing.contactMethods
            )
        } catch {
            return nil
        }
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

        // Extract contact info from description
        let contactInfo = ContactInfoExtractor.extractAll(from: description)

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
            views: 0,
            contactEmail: contactInfo.email,
            contactPhone: contactInfo.phone,
            contactMethods: contactInfo.methods
        )
    }

    // MARK: - Conversations

    func scrapeConversations() async throws -> [Conversation] {
        let url = URL(string: "\(Self.qrzBase)?conversations/")!
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode conversations HTML")
        }
        return try parseConversationsList(html: html)
    }

    func scrapeConversation(id: String, slug: String) async throws -> [Message] {
        let url = URL(string: "\(Self.qrzBase)?conversations/\(slug).\(id)/")!
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseFailed("Could not decode conversation HTML")
        }
        return try parseConversationMessages(html: html, conversationId: id)
    }

    func replyToConversation(id: String, slug: String, message: String) async throws {
        // GET conversation page to extract tokens
        let pageURL = URL(string: "\(Self.qrzBase)?conversations/\(slug).\(id)/")!
        let (pageData, _) = try await session.data(from: pageURL)
        let pageHTML = String(data: pageData, encoding: .utf8) ?? ""

        guard let xfToken = extractHiddenInput(html: pageHTML, name: "_xfToken") else {
            throw ScraperError.parseFailed("Could not find _xfToken for reply")
        }

        let lastDate = extractHiddenInput(html: pageHTML, name: "last_date") ?? ""

        // POST reply
        let replyURL = URL(string: "\(Self.qrzBase)?conversations/\(slug).\(id)/insert-reply")!
        var request = URLRequest(url: replyURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let form = [
            "message_html=\(urlEncode(message))",
            "last_date=\(urlEncode(lastDate))",
            "_xfToken=\(urlEncode(xfToken))",
        ].joined(separator: "&")
        request.httpBody = form.data(using: .utf8)

        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            throw ScraperError.networkError(
                NSError(domain: "QRZScraper", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Reply failed with status \(httpResponse.statusCode)"])
            )
        }
    }

    func startConversation(recipient: String, title: String, message: String) async throws {
        // GET the new conversation page to extract _xfToken
        let addURL = URL(string: "\(Self.qrzBase)?conversations/add&to=\(urlEncode(recipient))&title=\(urlEncode(title))")!
        let (pageData, _) = try await session.data(from: addURL)
        let pageHTML = String(data: pageData, encoding: .utf8) ?? ""

        guard let xfToken = extractHiddenInput(html: pageHTML, name: "_xfToken") else {
            throw ScraperError.parseFailed("Could not find _xfToken for new conversation")
        }

        // POST to create conversation
        let insertURL = URL(string: "\(Self.qrzBase)?conversations/insert")!
        var request = URLRequest(url: insertURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let form = [
            "recipients=\(urlEncode(recipient))",
            "title=\(urlEncode(title))",
            "message_html=\(urlEncode(message))",
            "_xfToken=\(urlEncode(xfToken))",
        ].joined(separator: "&")
        request.httpBody = form.data(using: .utf8)

        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            throw ScraperError.networkError(
                NSError(domain: "QRZScraper", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Start conversation failed with status \(httpResponse.statusCode)"])
            )
        }
    }

    // MARK: - Conversation Parsing

    private func parseConversationsList(html: String) throws -> [Conversation] {
        let document = try SwiftSoup.parse(html)
        let items = try document.select("li.discussionListItem")

        var conversations: [Conversation] = []

        for item in items {
            guard let idAttr = try? item.attr("id"),
                  idAttr.hasPrefix("conversation-") else {
                continue
            }
            let id = String(idAttr.replacingOccurrences(of: "conversation-", with: ""))

            let starterCallsign = (try? item.attr("data-author")) ?? ""

            // Title and slug from the link
            guard let titleLink = try item.select("h3.title a[href*=conversations/]").first() else {
                continue
            }
            let title = try titleLink.text().trimmingCharacters(in: .whitespaces)
            let href = try titleLink.attr("href")
            let slug = Self.conversationSlugFromURL(href, id: id)

            // Participants from .posterDate .username elements
            let usernameEls = try item.select(".posterDate .username")
            let participants = try usernameEls.compactMap { el -> String? in
                let name = try el.text().trimmingCharacters(in: .whitespaces)
                return name.isEmpty ? nil : name
            }

            // Created date - try abbr[data-time] first, then span.DateTime[title]
            let createdDate: Date
            if let dateEl = try item.select(".posterDate abbr.DateTime[data-time]").first(),
               let timestamp = Int64(try dateEl.attr("data-time")) {
                createdDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            } else if let dateEl = try item.select(".posterDate span.DateTime[title]").first() {
                createdDate = Self.parseXenForoDateTitle(try dateEl.attr("title"))
            } else {
                createdDate = Date()
            }

            // Reply count from dl.major dd
            let replyCount = try item.select("dl.major dd").first()
                .map { try $0.text().replacingOccurrences(of: ",", with: "") }
                .flatMap { Int($0) } ?? 0

            // Participant count from dl.minor dd
            let participantCount = try item.select("dl.minor dd").first()
                .map { try $0.text().replacingOccurrences(of: ",", with: "") }
                .flatMap { Int($0) } ?? 0

            // Last poster and date from .lastPostInfo
            let lastPoster = try item.select(".lastPostInfo .username").first()
                .map { try $0.text().trimmingCharacters(in: .whitespaces) } ?? ""

            let lastReplyDate: Date
            if let dateEl = try item.select(".lastPostInfo abbr.DateTime[data-time]").first(),
               let timestamp = Int64(try dateEl.attr("data-time")) {
                lastReplyDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            } else if let dateEl = try item.select(".lastPostInfo span.DateTime[title]").first() {
                lastReplyDate = Self.parseXenForoDateTitle(try dateEl.attr("title"))
            } else {
                lastReplyDate = createdDate
            }

            // Avatar URL
            let avatarURL = try item.select(".posterAvatar img").first()
                .flatMap { try? $0.attr("src") }
                .map { Self.resolveURL($0) }

            conversations.append(Conversation(
                id: id,
                title: title,
                slug: slug,
                starterCallsign: starterCallsign,
                participants: participants,
                replyCount: replyCount,
                participantCount: participantCount,
                lastPoster: lastPoster,
                createdDate: createdDate,
                lastReplyDate: lastReplyDate,
                avatarURL: avatarURL
            ))
        }

        return conversations
    }

    private func parseConversationMessages(html: String, conversationId: String) throws -> [Message] {
        let document = try SwiftSoup.parse(html)
        let messageElements = try document.select("ol#messageList li.message")

        var messages: [Message] = []

        for element in messageElements {
            guard let idAttr = try? element.attr("id"),
                  idAttr.hasPrefix("message-") else {
                continue
            }
            let messageId = String(idAttr.replacingOccurrences(of: "message-", with: ""))
            let author = (try? element.attr("data-author")) ?? ""

            // Body text (HTML stripped)
            let body = try element.select("blockquote.messageText").first()?.text()
                .trimmingCharacters(in: .whitespaces) ?? ""

            // Date from .messageMeta .DateTime[data-time]
            let date: Date
            if let dateEl = try element.select(".messageMeta abbr.DateTime[data-time]").first(),
               let timestamp = Int64(try dateEl.attr("data-time")) {
                date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            } else {
                date = Date()
            }

            // Avatar URL
            let avatarURL = try element.select(".messageUserBlock img").first()
                .flatMap { try? $0.attr("src") }
                .map { Self.resolveURL($0) }

            messages.append(Message(
                id: messageId,
                conversationId: conversationId,
                author: author,
                body: body,
                date: date,
                avatarURL: avatarURL
            ))
        }

        return messages
    }

    // MARK: - Helpers

    private static func conversationSlugFromURL(_ url: String, id: String) -> String {
        // URL format: index.php?conversations/some-slug.12345/
        guard let conversationsPart = url.split(separator: "conversations/").last else { return "" }
        let str = String(conversationsPart)
        let suffix = ".\(id)/"
        if str.hasSuffix(suffix) {
            return String(str.dropLast(suffix.count))
        }
        // Fallback: strip after last dot
        guard let dotPos = str.lastIndex(of: ".") else { return "" }
        return String(str[str.startIndex..<dotPos])
    }

    private static func parseXenForoDateTitle(_ title: String) -> Date {
        // Format: "Jan 30, 2026 at 7:19 PM"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.date(from: title) ?? Date()
    }

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
