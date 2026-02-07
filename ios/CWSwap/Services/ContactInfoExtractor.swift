import Foundation

enum ContactInfoExtractor {
    // MARK: - Email

    private static let emailRegex = try! NSRegularExpression(
        pattern: #"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#
    )

    private static let falsePositiveEmailDomains = [
        "example.com", "test.com", "placeholder.com",
    ]

    static func extractEmail(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = emailRegex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        let email = String(text[matchRange]).lowercased()
        if falsePositiveEmailDomains.contains(where: { email.hasSuffix("@\($0)") }) {
            return nil
        }
        return email
    }

    // MARK: - Phone

    private static let phoneRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(?:\(?(\d{3})\)?[\s.\-]?(\d{3})[\s.\-]?(\d{4}))(?!\d)"#
    )

    static func extractPhone(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = phoneRegex.firstMatch(in: text, range: range),
              let fullRange = Range(match.range, in: text) else {
            return nil
        }
        let raw = String(text[fullRange])
        let digits = raw.filter(\.isWholeNumber)
        guard digits.count == 10 else { return nil }
        // Format as (xxx) xxx-xxxx
        let area = digits.prefix(3)
        let mid = digits.dropFirst(3).prefix(3)
        let last = digits.suffix(4)
        return "(\(area)) \(mid)-\(last)"
    }

    // MARK: - Contact/Payment Methods

    private static let methodKeywords: [(keyword: String, display: String)] = [
        ("zelle", "Zelle"),
        ("paypal", "PayPal"),
        ("venmo", "Venmo"),
        ("cash app", "Cash App"),
        ("money order", "Money Order"),
        ("cashier's check", "Cashier's Check"),
        ("cashiers check", "Cashier's Check"),
        ("cash on pickup", "Cash on Pickup"),
        ("local pickup", "Local Pickup"),
        ("usps money order", "USPS Money Order"),
    ]

    static func extractContactMethods(from text: String) -> [String] {
        let lowered = text.lowercased()
        var found: [String] = []
        for (keyword, display) in methodKeywords {
            if lowered.contains(keyword), !found.contains(display) {
                found.append(display)
            }
        }
        return found
    }

    // MARK: - Combined

    struct ContactInfo: Sendable {
        let email: String?
        let phone: String?
        let methods: [String]
    }

    static func extractAll(from text: String) -> ContactInfo {
        ContactInfo(
            email: extractEmail(from: text),
            phone: extractPhone(from: text),
            methods: extractContactMethods(from: text)
        )
    }
}
