import Foundation

// MARK: - GraphQL Response Wrapper

struct HiBidGraphQLResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T?
    let errors: [HiBidGraphQLError]?
}

struct HiBidGraphQLError: Decodable, Sendable {
    let message: String
    let locations: [HiBidErrorLocation]?
    let path: [String]?
}

struct HiBidErrorLocation: Decodable, Sendable {
    let line: Int
    let column: Int
}

// MARK: - LotSearch Response

struct HiBidLotSearchData: Decodable, Sendable {
    let lotSearch: HiBidLotSearchResult
}

struct HiBidLotSearchResult: Decodable, Sendable {
    let pagedResults: HiBidPagedResults
}

struct HiBidPagedResults: Decodable, Sendable {
    let pageLength: Int
    let pageNumber: Int
    let totalCount: Int
    let filteredCount: Int
    let results: [HiBidLot]
}

// MARK: - Lot

struct HiBidLot: Decodable, Sendable {
    let auction: HiBidAuctionMinimum?
    let bidAmount: Double?
    let bidQuantity: Int?
    let description: String?
    let featuredPicture: HiBidPicture?
    let id: Int
    let itemId: Int?
    let lead: String?
    let lotNumber: String?
    let lotState: HiBidLotState?
    let pictureCount: Int?
    let quantity: Int?
    let shippingOffered: Bool?
    let site: HiBidSite?
}

struct HiBidAuctionMinimum: Decodable, Sendable {
    let id: Int?
    let name: String?
    let auctioneer: HiBidAuctioneer?
    let status: String?
    let startDate: String?
    let endDate: String?
}

struct HiBidAuctioneer: Decodable, Sendable {
    let id: Int?
    let name: String?
    let subdomain: String?
}

struct HiBidPicture: Decodable, Sendable {
    let description: String?
    let fullSizeLocation: String?
    let height: Int?
    let hdThumbnailLocation: String?
    let thumbnailLocation: String?
    let width: Int?
}

struct HiBidLotState: Decodable, Sendable {
    let bidCount: Int?
    let bidMax: Double?
    let bidMaxTotal: Double?
    let buyNow: Double?
    let highBid: Double?
    let isClosed: Bool?
    let isLive: Bool?
    let isNotYetLive: Bool?
    let minBid: Double?
    let priceRealized: Double?
    let reserveSatisfied: Bool?
    let showReserveStatus: Bool?
    let status: String?
    let timeLeft: String?
    let timeLeftSeconds: Int?
}

struct HiBidSite: Decodable, Sendable {
    let domain: String?
    let subdomain: String?
}

// MARK: - AuctionSearch Response

struct HiBidAuctionSearchData: Decodable, Sendable {
    let auctionSearch: HiBidAuctionSearchResult
}

struct HiBidAuctionSearchResult: Decodable, Sendable {
    let pagedResults: HiBidAuctionPagedResults
}

struct HiBidAuctionPagedResults: Decodable, Sendable {
    let totalCount: Int
    let results: [HiBidAuctionResult]
}

struct HiBidAuctionResult: Decodable, Sendable {
    let id: Int
    let name: String?
    let auctioneer: HiBidAuctioneer?
    let status: String?
    let startDate: String?
    let endDate: String?
    let lotCount: Int?
}

// MARK: - Configuration

struct HiBidAuctioneerConfig: Sendable {
    let subdomain: String
    let name: String
    let pinnedAuctionIds: [Int]

    static let knownAuctioneers: [HiBidAuctioneerConfig] = [
        HiBidAuctioneerConfig(
            subdomain: "schulmanauction",
            name: "Schulman Auction & Realty",
            pinnedAuctionIds: []
        ),
    ]
}

// MARK: - Errors

enum HiBidError: LocalizedError {
    case graphqlFailed(String)
    case decodingFailed(String)
    case noData
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .graphqlFailed(let msg): "HiBid API error: \(msg)"
        case .decodingFailed(let msg): "HiBid decode error: \(msg)"
        case .noData: "No data returned from HiBid."
        case .rateLimited: "HiBid temporarily unavailable. Try again later."
        }
    }
}
