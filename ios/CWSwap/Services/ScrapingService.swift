import Foundation

struct ScrapingService: Sendable {
    private let qrzScraper = QRZScraper()
    private let qthScraper = QTHScraper()
    private let hamEstateScraper = HamEstateScraper()
    private let ebayScraper = EbayScraper()
    private let craigslistScraper = CraigslistScraper()

    struct SyncProgress: Sendable {
        let completedSteps: Int
        let totalSteps: Int
        let source: ListingSource
        let errorMessage: String?

        init(completedSteps: Int, totalSteps: Int, source: ListingSource, errorMessage: String? = nil) {
            self.completedSteps = completedSteps
            self.totalSteps = totalSteps
            self.source = source
            self.errorMessage = errorMessage
        }

        var fraction: Double {
            totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
        }
    }

    func fetchListings(
        page: Int = 1,
        source: ListingSource? = nil,
        query: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        hasPhoto: Bool? = nil,
        hideSold: Bool = true,
        sort: String? = nil,
        ebayCategoryIds: [String] = [],
        craigslistRegions: [CraigslistRegion] = [],
        craigslistSearchTerms: [CraigslistSearchTerm] = []
    ) async throws -> [Listing] {
        var allListings: [Listing] = []

        // Scrape from requested source(s)
        if source == nil || source == .qth {
            do {
                let qthListings = try await qthScraper.scrapeFullPage(page: page)
                allListings.append(contentsOf: qthListings)
            } catch {
                // QTH failure is non-fatal
            }
        }

        if source == nil || source == .qrz {
            do {
                let qrzListings = try await qrzScraper.scrapeFullPage(page: page)
                allListings.append(contentsOf: qrzListings)
            } catch {
                // QRZ failure is non-fatal if we have QTH results
                if allListings.isEmpty { throw error }
            }
        }

        if source == nil || source == .hamestate {
            do {
                let hamEstateListings = try await hamEstateScraper.scrapeFullPage(page: page)
                allListings.append(contentsOf: hamEstateListings)
            } catch {
                // HamEstate failure is non-fatal
            }
        }

        if source == nil || source == .ebay {
            do {
                let ebayListings = try await ebayScraper.fetchListings(
                    page: page,
                    query: query,
                    categoryIds: ebayCategoryIds
                )
                allListings.append(contentsOf: ebayListings)
            } catch {
                // eBay failure is non-fatal
            }
        }

        if source == nil || source == .craigslist {
            do {
                let clListings = try await craigslistScraper.scrapeFullPage(
                    regions: craigslistRegions,
                    terms: craigslistSearchTerms
                )
                allListings.append(contentsOf: clListings)
            } catch {
                // Craigslist failure is non-fatal
            }
        }

        return Self.applyFilters(
            to: allListings,
            query: query,
            priceMin: priceMin, priceMax: priceMax,
            hasPhoto: hasPhoto, hideSold: hideSold, sort: sort
        )
    }

    /// Progressive scraping: yields listings as they arrive via AsyncStream.
    /// QTH arrives as a batch (single request), QRZ arrives one thread at a time.
    func scrapeProgressively(
        page: Int = 1,
        source: ListingSource? = nil,
        ebayCategoryIds: [String] = [],
        craigslistRegions: [CraigslistRegion] = [],
        craigslistSearchTerms: [CraigslistSearchTerm] = []
    ) -> (listings: AsyncStream<Listing>, progress: AsyncStream<SyncProgress>) {
        let (listingStream, listingCont) = AsyncStream<Listing>.makeStream()
        let (progressStream, progressCont) = AsyncStream<SyncProgress>.makeStream()

        // Launch all sources in parallel
        Task {
            await withTaskGroup(of: Void.self) { group in
                // QTH: single request, all at once
                if source == nil || source == .qth {
                    group.addTask {
                        progressCont.yield(SyncProgress(completedSteps: 0, totalSteps: 1, source: .qth))
                        do {
                            let qthListings = try await self.qthScraper.scrapeFullPage(page: page)
                            for listing in qthListings {
                                listingCont.yield(listing)
                            }
                        } catch {
                            // QTH failure is non-fatal
                        }
                        progressCont.yield(SyncProgress(completedSteps: 1, totalSteps: 1, source: .qth))
                    }
                }

                // QRZ: one thread at a time with progress
                if source == nil || source == .qrz {
                    group.addTask {
                        do {
                            try await self.qrzScraper.scrapeFullPage(
                                page: page,
                                onListing: { listing in
                                    listingCont.yield(listing)
                                },
                                onProgress: { completed, total in
                                    progressCont.yield(SyncProgress(completedSteps: completed, totalSteps: total, source: .qrz))
                                }
                            )
                        } catch {
                            // QRZ failure is non-fatal
                        }
                    }
                }

                // eBay: single API request, batch result
                if source == nil || source == .ebay {
                    group.addTask {
                        progressCont.yield(SyncProgress(completedSteps: 0, totalSteps: 1, source: .ebay))
                        do {
                            let ebayListings = try await self.ebayScraper.fetchListings(
                                page: page,
                                categoryIds: ebayCategoryIds
                            )
                            for listing in ebayListings {
                                listingCont.yield(listing)
                            }
                            progressCont.yield(SyncProgress(completedSteps: 1, totalSteps: 1, source: .ebay))
                        } catch {
                            progressCont.yield(SyncProgress(
                                completedSteps: 1, totalSteps: 1, source: .ebay,
                                errorMessage: error.localizedDescription
                            ))
                        }
                    }
                }

                // Craigslist: RSS feeds + detail page scraping with progress
                if source == nil || source == .craigslist {
                    group.addTask {
                        do {
                            try await self.craigslistScraper.scrapeFullPage(
                                regions: craigslistRegions,
                                terms: craigslistSearchTerms,
                                onListing: { listing in
                                    listingCont.yield(listing)
                                },
                                onProgress: { completed, total in
                                    progressCont.yield(SyncProgress(completedSteps: completed, totalSteps: total, source: .craigslist))
                                }
                            )
                        } catch {
                            progressCont.yield(SyncProgress(
                                completedSteps: 1, totalSteps: 1, source: .craigslist,
                                errorMessage: error.localizedDescription
                            ))
                        }
                    }
                }
            }

            // HamEstate: one product at a time with progress
            if source == nil || source == .hamestate {
                do {
                    try await hamEstateScraper.scrapeFullPage(
                        page: page,
                        onListing: { listing in
                            listingCont.yield(listing)
                        },
                        onProgress: { completed, total in
                            progressCont.yield(SyncProgress(completedSteps: completed, totalSteps: total, source: .hamestate))
                        }
                    )
                } catch {
                    // HamEstate failure is non-fatal
                }
            }

            listingCont.finish()
            progressCont.finish()
        }

        return (listingStream, progressStream)
    }

    static func applyFilters(
        to listings: [Listing],
        source: ListingSource? = nil,
        query: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        hasPhoto: Bool? = nil,
        hideSold: Bool = true,
        sort: String? = nil
    ) -> [Listing] {
        var filtered = listings

        if let source {
            filtered = filtered.filter { $0.source == source }
        }
        if hideSold {
            filtered = filtered.filter { $0.status != .sold }
        }
        if let query, !query.isEmpty {
            let lowered = query.lowercased()
            filtered = filtered.filter {
                $0.title.lowercased().contains(lowered)
                || $0.description.lowercased().contains(lowered)
                || $0.callsign.lowercased().contains(lowered)
            }
        }
        if let priceMin {
            filtered = filtered.filter { ($0.price?.amount ?? 0) >= priceMin }
        }
        if let priceMax {
            filtered = filtered.filter { ($0.price?.amount ?? Double.infinity) <= priceMax }
        }
        if hasPhoto == true {
            filtered = filtered.filter { $0.hasPhotos }
        }

        switch sort {
        case "oldest":
            filtered.sort { $0.datePosted < $1.datePosted }
        case "price_asc":
            filtered.sort { ($0.price?.amount ?? 0) < ($1.price?.amount ?? 0) }
        case "price_desc":
            filtered.sort { ($0.price?.amount ?? 0) > ($1.price?.amount ?? 0) }
        default:
            filtered.sort { $0.datePosted > $1.datePosted }
        }

        return filtered
    }

    func loginQRZ(username: String, password: String) async throws {
        try await qrzScraper.login(username: username, password: password)
    }
}
