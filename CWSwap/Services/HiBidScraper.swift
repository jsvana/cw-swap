import Foundation

final class HiBidScraper: Sendable {
    private static let graphqlURL = "https://hibid.com/graphql"
    private static let pageLength = 50

    /// Patterns indicating an informational lot (payment terms, shipping, etc.) rather than equipment.
    private static let infoLotPatterns: [String] = [
        "PAYMENT", "BIDDING", "SHIPPING", "PREVIEW", "PICKUP",
        "EQUIPMENT TESTING", "TERMS", "CONDITIONS", "INSPECTION",
        "REMOVAL", "CHECKOUT", "IMPORTANT",
    ]

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func fetchListings(page: Int = 1) async throws -> [Listing] {
        var allListings: [Listing] = []

        for auctioneer in HiBidAuctioneerConfig.knownAuctioneers {
            do {
                let auctionIds: [Int]
                if auctioneer.pinnedAuctionIds.isEmpty {
                    auctionIds = try await discoverActiveAuctions(subdomain: auctioneer.subdomain)
                } else {
                    auctionIds = auctioneer.pinnedAuctionIds
                }

                for auctionId in auctionIds {
                    let lots = try await fetchLots(
                        subdomain: auctioneer.subdomain,
                        auctionId: auctionId,
                        page: page
                    )
                    let listings = lots.compactMap { lot in
                        mapToListing(lot, auctioneerName: auctioneer.name, subdomain: auctioneer.subdomain)
                    }
                    allListings.append(contentsOf: listings)
                }
            } catch {
                // Individual auctioneer failure is non-fatal
            }
        }

        return allListings
    }

    /// Progressive variant for ScrapingService integration.
    func fetchListings(
        page: Int = 1,
        onListing: (Listing) -> Void,
        onProgress: (Int, Int) -> Void
    ) async throws {
        let auctioneers = HiBidAuctioneerConfig.knownAuctioneers
        let total = auctioneers.count
        var completed = 0

        onProgress(0, total)

        for auctioneer in auctioneers {
            do {
                let auctionIds: [Int]
                if auctioneer.pinnedAuctionIds.isEmpty {
                    auctionIds = try await discoverActiveAuctions(subdomain: auctioneer.subdomain)
                } else {
                    auctionIds = auctioneer.pinnedAuctionIds
                }

                for auctionId in auctionIds {
                    let lots = try await fetchLots(
                        subdomain: auctioneer.subdomain,
                        auctionId: auctionId,
                        page: page
                    )
                    for lot in lots {
                        if let listing = mapToListing(lot, auctioneerName: auctioneer.name, subdomain: auctioneer.subdomain) {
                            onListing(listing)
                        }
                    }
                }
            } catch {
                // Individual auctioneer failure is non-fatal
            }

            completed += 1
            onProgress(completed, total)
        }
    }

    // MARK: - GraphQL Queries

    private func fetchLots(subdomain: String, auctionId: Int, page: Int) async throws -> [HiBidLot] {
        let query = """
        query LotSearch($auctionId: Int, $pageNumber: Int!, $pageLength: Int!, $countAsView: Boolean = false, $hideGoogle: Boolean = false, $status: AuctionLotStatus = null, $sortOrder: EventItemSortOrder = null) {
          lotSearch(
            input: {
              auctionId: $auctionId,
              status: $status,
              sortOrder: $sortOrder,
              countAsView: $countAsView,
              hideGoogle: $hideGoogle
            }
            pageNumber: $pageNumber
            pageLength: $pageLength
            sortDirection: DESC
          ) {
            pagedResults {
              pageLength
              pageNumber
              totalCount
              filteredCount
              results {
                auction {
                  id
                  name
                  auctioneer {
                    id
                    name
                    subdomain
                  }
                  status
                }
                bidAmount
                bidQuantity
                description
                featuredPicture {
                  description
                  fullSizeLocation
                  height
                  hdThumbnailLocation
                  thumbnailLocation
                  width
                }
                id
                itemId
                lead
                lotNumber
                lotState {
                  bidCount
                  bidMax
                  bidMaxTotal
                  buyNow
                  highBid
                  isClosed
                  isLive
                  isNotYetLive
                  minBid
                  priceRealized
                  reserveSatisfied
                  showReserveStatus
                  status
                  timeLeft
                  timeLeftSeconds
                }
                pictureCount
                quantity
                shippingOffered
                site {
                  domain
                  subdomain
                }
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "auctionId": auctionId,
            "pageNumber": page,
            "pageLength": Self.pageLength,
            "countAsView": false,
            "hideGoogle": false,
        ]

        let body: [String: Any] = [
            "query": query,
            "variables": variables,
        ]

        let data = try await performGraphQL(body: body, subdomain: subdomain)

        let response: HiBidGraphQLResponse<HiBidLotSearchData>
        do {
            let decoder = JSONDecoder()
            response = try decoder.decode(HiBidGraphQLResponse<HiBidLotSearchData>.self, from: data)
        } catch {
            let raw = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw HiBidError.decodingFailed("LotSearch decode failed: \(error.localizedDescription) | Raw: \(raw)")
        }

        if let errors = response.errors, let first = errors.first {
            throw HiBidError.graphqlFailed(first.message)
        }

        guard let results = response.data?.lotSearch.pagedResults.results else {
            return []
        }

        return results
    }

    private func discoverActiveAuctions(subdomain: String) async throws -> [Int] {
        let query = """
        query AuctionSearch($pageNumber: Int!, $pageLength: Int!, $status: AuctionLotStatus = null) {
          auctionSearch(
            input: { status: $status }
            pageNumber: $pageNumber
            pageLength: $pageLength
          ) {
            pagedResults {
              totalCount
              results {
                id
                name
                auctioneer {
                  id
                  name
                  subdomain
                }
                status
                lotCount
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "pageNumber": 1,
            "pageLength": 20,
        ]

        let body: [String: Any] = [
            "query": query,
            "variables": variables,
        ]

        let data = try await performGraphQL(body: body, subdomain: subdomain)

        let response: HiBidGraphQLResponse<HiBidAuctionSearchData>
        do {
            let decoder = JSONDecoder()
            response = try decoder.decode(HiBidGraphQLResponse<HiBidAuctionSearchData>.self, from: data)
        } catch {
            return []
        }

        guard let results = response.data?.auctionSearch.pagedResults.results else {
            return []
        }

        // Return IDs of auctions that appear active (have lots)
        return results
            .filter { ($0.lotCount ?? 0) > 0 }
            .map(\.id)
    }

    // MARK: - HTTP

    private func performGraphQL(body: [String: Any], subdomain: String) async throws -> Data {
        guard let url = URL(string: Self.graphqlURL) else {
            throw HiBidError.graphqlFailed("Invalid GraphQL URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(subdomain.uppercased(), forHTTPHeaderField: "site_subdomain")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 || httpResponse.statusCode == 403 {
                throw HiBidError.rateLimited
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw HiBidError.graphqlFailed("HTTP \(httpResponse.statusCode)")
            }
        }

        return data
    }

    // MARK: - Mapping

    private func mapToListing(_ lot: HiBidLot, auctioneerName: String, subdomain: String) -> Listing? {
        let lead = lot.lead ?? ""

        // Filter out informational lots
        if Self.isInfoLot(lead: lead) {
            return nil
        }

        let lotState = lot.lotState
        let auctionId = lot.auction?.id ?? 0

        // Determine auction status
        let auctionStatus: AuctionStatus
        if lotState?.isClosed == true {
            auctionStatus = .closed
        } else if lotState?.isLive == true {
            auctionStatus = .live
        } else if lotState?.isNotYetLive == true {
            auctionStatus = .notYetLive
        } else {
            auctionStatus = .open
        }

        // Compute absolute close time from relative seconds
        let closesAt: Date?
        if let seconds = lotState?.timeLeftSeconds, seconds > 0 {
            closesAt = Date().addingTimeInterval(TimeInterval(seconds))
        } else {
            closesAt = nil
        }

        // Build bid URL
        let lotSlug = Self.slugify(lead)
        let bidUrl = "https://\(subdomain).hibid.com/lot/\(lot.id)/\(lotSlug)?auctionId=\(auctionId)"

        let auctionMeta = AuctionMeta(
            currentBid: lotState?.highBid,
            minBid: lotState?.minBid,
            bidCount: lotState?.bidCount ?? 0,
            highBid: lotState?.highBid,
            buyNow: (lotState?.buyNow ?? 0) > 0 ? lotState?.buyNow : nil,
            auctionStatus: auctionStatus,
            timeLeftSeconds: lotState?.timeLeftSeconds,
            timeLeftDisplay: lotState?.timeLeft,
            closesAt: closesAt,
            reserveMet: lotState?.showReserveStatus == true ? lotState?.reserveSatisfied : nil,
            lotNumber: lot.lotNumber ?? "",
            auctionId: auctionId,
            lotId: lot.id,
            shippingOffered: lot.shippingOffered ?? false,
            bidUrl: bidUrl,
            auctioneerName: auctioneerName
        )

        // Photo URLs
        var photoUrls: [String] = []
        if let fullSize = lot.featuredPicture?.fullSizeLocation, !fullSize.isEmpty {
            photoUrls.append(fullSize)
        }

        // Thumbnail for listing card
        let thumbnailUrl = lot.featuredPicture?.hdThumbnailLocation
            ?? lot.featuredPicture?.thumbnailLocation

        // Use high bid as price for unified sorting
        let price: Price?
        if let highBid = lotState?.highBid, highBid > 0 {
            price = Price(amount: highBid, currency: "USD", includesShipping: false, obo: false)
        } else {
            price = nil
        }

        // Clean description: replace \r with newlines
        let rawDescription = lot.description ?? ""
        let description = rawDescription
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Category mapping from title keywords
        let category = Self.mapCategory(title: lead, description: description)

        // Use thumbnail as first photo URL if no full-size available
        if photoUrls.isEmpty, let thumb = thumbnailUrl, !thumb.isEmpty {
            photoUrls.append(thumb)
        }

        return Listing(
            id: "hibid:\(lot.id)",
            source: .hibid,
            sourceUrl: bidUrl,
            title: lead,
            description: description,
            descriptionHtml: rawDescription,
            status: auctionStatus == .closed ? .sold : .forSale,
            callsign: auctioneerName,
            memberId: nil,
            avatarUrl: nil,
            price: price,
            photoUrls: photoUrls,
            category: category,
            datePosted: Date(),
            dateModified: nil,
            replies: 0,
            views: 0,
            contactEmail: nil,
            contactPhone: nil,
            contactMethods: ["hibid"],
            auctionMeta: auctionMeta
        )
    }

    // MARK: - Helpers

    private static func isInfoLot(lead: String) -> Bool {
        let upper = lead.uppercased()
        // Check for known info patterns
        if infoLotPatterns.contains(where: { upper.contains($0) }) {
            return true
        }
        // Also filter lots that are just exclamation-heavy short titles
        if lead.count < 20 && lead.contains("!") {
            let stripped = lead.replacingOccurrences(of: "!", with: "").trimmingCharacters(in: .whitespaces)
            if infoLotPatterns.contains(where: { stripped.uppercased().contains($0) }) {
                return true
            }
        }
        return false
    }

    private static func slugify(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func mapCategory(title: String, description: String) -> ListingCategory? {
        let text = (title + " " + description).lowercased()

        if text.contains("transceiver") || text.contains("receiver") || text.contains("radio") {
            if text.contains("vhf") || text.contains("uhf") || text.contains("2m") || text.contains("70cm") {
                return .vhfUhfRadios
            }
            if text.contains("vintage") || text.contains("collins") || text.contains("drake") || text.contains("hallicrafters") || text.contains("national") {
                return .antiqueRadios
            }
            return .hfRadios
        }
        if text.contains("antenna") || text.contains("yagi") || text.contains("dipole") || text.contains("beam") || text.contains("vertical") {
            return text.contains("vhf") || text.contains("uhf") ? .vhfUhfAntennas : .hfAntennas
        }
        if text.contains("amplifier") || text.contains("linear") || text.contains("amp ") {
            return text.contains("vhf") || text.contains("uhf") ? .vhfUhfAmplifiers : .hfAmplifiers
        }
        if text.contains("key") || text.contains("keyer") || text.contains("paddle") || text.contains("morse") || text.contains("bug") && text.contains("vibroplex") {
            return .keys
        }
        if text.contains("tower") || text.contains("mast") || text.contains("crank") {
            return .towers
        }
        if text.contains("rotator") || text.contains("rotor") {
            return .rotators
        }
        if text.contains("oscilloscope") || text.contains("meter") || text.contains("analyzer") || text.contains("test") || text.contains("swr") || text.contains("dummy load") {
            return .testEquipment
        }
        if text.contains("computer") || text.contains("sdr") {
            return .computers
        }
        if text.contains("microphone") || text.contains("headset") || text.contains("power supply") || text.contains("tuner") || text.contains("cable") || text.contains("coax") {
            return .accessories
        }

        return nil
    }
}
