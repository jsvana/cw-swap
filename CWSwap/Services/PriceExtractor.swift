import Foundation

enum PriceExtractor {
    private static let priceRegex = try! NSRegularExpression(pattern: #"\$\s?([\d,]+(?:\.\d{2})?)"#)
    private static let oboRegex = try! NSRegularExpression(pattern: #"(?i)\b(obo|or best offer|best offer)\b"#)
    private static let shippedRegex = try! NSRegularExpression(pattern: #"(?i)\b(shipped|free shipping|includes shipping)\b"#)
    private static let plusShippingRegex = try! NSRegularExpression(pattern: #"(?i)\b(plus shipping|\+ shipping|buyer pays shipping)\b"#)

    static func extractPrice(from text: String) -> Price? {
        let range = NSRange(text.startIndex..., in: text)

        guard let match = priceRegex.firstMatch(in: text, range: range),
              let amountRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let amountStr = String(text[amountRange]).replacingOccurrences(of: ",", with: "")
        guard let amount = Double(amountStr), amount >= 1.0, amount <= 500_000.0 else {
            return nil
        }

        let hasObo = oboRegex.firstMatch(in: text, range: range) != nil
        let hasShipped = shippedRegex.firstMatch(in: text, range: range) != nil
        let hasPlusShipping = plusShippingRegex.firstMatch(in: text, range: range) != nil
        let includesShipping = hasShipped && !hasPlusShipping

        return Price(
            amount: amount,
            currency: "USD",
            includesShipping: includesShipping,
            obo: hasObo
        )
    }
}
