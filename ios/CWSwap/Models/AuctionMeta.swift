import Foundation

enum AuctionStatus: String, Codable, Hashable, Sendable {
    case open
    case closing
    case closed
    case notYetLive = "not_yet_live"
    case live

    var displayName: String {
        switch self {
        case .open: "Open"
        case .closing: "Closing"
        case .closed: "Closed"
        case .notYetLive: "Not Yet Live"
        case .live: "Live"
        }
    }

    var isActive: Bool {
        switch self {
        case .open, .closing, .live: true
        case .closed, .notYetLive: false
        }
    }
}

struct AuctionMeta: Hashable, Codable, Sendable {
    let currentBid: Double?
    let minBid: Double?
    let bidCount: Int
    let highBid: Double?
    let buyNow: Double?
    let auctionStatus: AuctionStatus
    let timeLeftSeconds: Int?
    let timeLeftDisplay: String?
    let closesAt: Date?
    let reserveMet: Bool?
    let lotNumber: String
    let auctionId: Int
    let lotId: Int
    let shippingOffered: Bool
    let bidUrl: String
    let auctioneerName: String

    enum CodingKeys: String, CodingKey {
        case currentBid = "current_bid"
        case minBid = "min_bid"
        case bidCount = "bid_count"
        case highBid = "high_bid"
        case buyNow = "buy_now"
        case auctionStatus = "auction_status"
        case timeLeftSeconds = "time_left_seconds"
        case timeLeftDisplay = "time_left_display"
        case closesAt = "closes_at"
        case reserveMet = "reserve_met"
        case lotNumber = "lot_number"
        case auctionId = "auction_id"
        case lotId = "lot_id"
        case shippingOffered = "shipping_offered"
        case bidUrl = "bid_url"
        case auctioneerName = "auctioneer_name"
    }

    var formattedBid: String? {
        guard let highBid, highBid > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = highBid.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: highBid))
    }

    var formattedBuyNow: String? {
        guard let buyNow, buyNow > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = buyNow.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: buyNow))
    }

    var bidSummary: String {
        let bidText = formattedBid ?? "$0"
        let countText = bidCount == 1 ? "1 bid" : "\(bidCount) bids"
        return "\(bidText) (\(countText))"
    }

    var timeLeftColor: TimeLeftColor {
        guard auctionStatus.isActive else { return .gray }
        guard let seconds = computedTimeLeftSeconds else { return .gray }
        if seconds < 3600 { return .red }
        if seconds < 86400 { return .amber }
        return .green
    }

    enum TimeLeftColor: Sendable {
        case green, amber, red, gray
    }

    /// Computed time left from closesAt, falling back to timeLeftSeconds
    var computedTimeLeftSeconds: Int? {
        if let closesAt {
            let remaining = Int(closesAt.timeIntervalSinceNow)
            return max(remaining, 0)
        }
        return timeLeftSeconds
    }

    var computedTimeLeftDisplay: String {
        guard auctionStatus.isActive else {
            return auctionStatus.displayName
        }
        guard let seconds = computedTimeLeftSeconds, seconds > 0 else {
            return "Ended"
        }
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var bidURL: URL? {
        URL(string: bidUrl)
    }
}
