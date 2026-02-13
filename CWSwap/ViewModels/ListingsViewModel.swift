import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class ListingsViewModel {
    private let scrapingService = ScrapingService()
    private var listingStore: ListingStore?
    var ebayCategoryStore = EbayCategoryStore()
    var craigslistRegionStore = CraigslistRegionStore()

    /// Maximum listings held in memory. Oldest evicted when exceeded.
    private static let maxInMemoryListings = 500

    var listings: [Listing] = []
    var isLoading = false
    var error: Error?
    var hasMore = true

    // Sync progress
    var syncProgress: Double = 0
    var syncStatus: String = ""
    var isSyncing = false
    var sourceErrors: [String] = []

    // Filters
    var selectedSource: ListingSource?
    var searchQuery = ""
    var sortOption: SortOption = .newest
    var priceMin: Double?
    var priceMax: Double?
    var hasPhotoOnly = false
    var hideSold = true
    var hideSeen = true

    private var currentPage = 1
    private var seenIdsSnapshot: Set<String> = []
    /// Incremented on each loadListings call; stale loads check this to bail out.
    private var loadGeneration = 0
    // All scraped listings before filtering (for merge tracking)
    private var allScrapedListings: [String: Listing] = [:]
    /// Insertion order for eviction (oldest first)
    private var insertionOrder: [String] = []

    enum SortOption: String, CaseIterable, Identifiable, Sendable {
        case newest
        case oldest
        case priceAsc = "price_asc"
        case priceDesc = "price_desc"
        case closingSoon = "closing_soon"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .newest: "Newest"
            case .oldest: "Oldest"
            case .priceAsc: "Price: Low \u{2192} High"
            case .priceDesc: "Price: High \u{2192} Low"
            case .closingSoon: "Closing Soon"
            }
        }
    }

    var hasActiveFilters: Bool {
        selectedSource != nil || !searchQuery.isEmpty
            || priceMin != nil || priceMax != nil || hasPhotoOnly || !hideSold || !hideSeen
    }

    func setModelContext(_ context: ModelContext) {
        self.listingStore = ListingStore(modelContext: context)
    }

    func loadListings() async {
        loadGeneration &+= 1
        let generation = loadGeneration

        // Reload store state from UserDefaults in case Settings changed it
        craigslistRegionStore.reloadFromDefaults()
        ebayCategoryStore.reloadFromDefaults()

        isLoading = true
        isSyncing = true
        syncProgress = 0
        syncStatus = "Loading cached data..."
        error = nil
        sourceErrors = []
        currentPage = 1
        allScrapedListings.removeAll()
        insertionOrder.removeAll()

        // Snapshot seen IDs once per load so items don't vanish mid-scroll
        if hideSeen, let store = listingStore {
            seenIdsSnapshot = store.seenListingIds()
        } else {
            seenIdsSnapshot = []
        }

        // Show cached data immediately (or clear if no cache)
        if let store = listingStore {
            do {
                let cached = try store.fetchCachedListings(
                    source: selectedSource,
                    query: searchQuery.isEmpty ? nil : searchQuery,
                    priceMin: priceMin,
                    priceMax: priceMax,
                    hasPhoto: hasPhotoOnly ? true : nil,
                    hideSold: hideSold,
                    hideSeen: hideSeen,
                    sort: sortOption.rawValue
                )
                listings = cached
                for listing in cached {
                    allScrapedListings[listing.id] = listing
                }
            } catch {
                listings = []
            }
        } else {
            listings = []
        }

        // Progressive scrape
        let (listingStream, progressStream) = scrapingService.scrapeProgressively(
            page: 1,
            source: selectedSource,
            ebayCategoryIds: ebayCategoryStore.enabledCategoryIds,
            craigslistRegions: craigslistRegionStore.enabledRegions,
            craigslistSearchTerms: craigslistRegionStore.enabledSearchTerms
        )

        // Consume progress updates in a separate task
        let progressTask = Task {
            for await progress in progressStream {
                guard generation == self.loadGeneration else { break }
                self.syncProgress = progress.fraction
                let sourceName = progress.source.displayName
                if let errorMsg = progress.errorMessage {
                    self.sourceErrors.append("\(sourceName): \(errorMsg)")
                } else if progress.completedSteps < progress.totalSteps {
                    self.syncStatus = "Syncing \(sourceName)... \(progress.completedSteps)/\(progress.totalSteps)"
                } else {
                    self.syncStatus = "\(sourceName) complete"
                }
            }
        }

        // Consume listings as they arrive and merge
        var newCount = 0
        var updatedCount = 0
        var pendingPersist: [Listing] = []
        let batchSize = 20
        for await listing in listingStream {
            guard generation == loadGeneration else { break }
            let merged = mergeListing(listing)
            if merged == .inserted { newCount += 1 }
            if merged == .updated { updatedCount += 1 }

            pendingPersist.append(listing)

            // Persist and refresh UI in batches
            if pendingPersist.count >= batchSize {
                if let store = listingStore {
                    _ = try? store.upsertListings(pendingPersist)
                }
                pendingPersist.removeAll()
                reapplyFilters()
            }
        }

        // Bail out if superseded by a newer load
        guard generation == loadGeneration else {
            progressTask.cancel()
            return
        }

        // Flush remaining
        if !pendingPersist.isEmpty {
            if let store = listingStore {
                _ = try? store.upsertListings(pendingPersist)
            }
        }
        reapplyFilters()

        await progressTask.value
        hasMore = newCount > 0 || updatedCount > 0

        isSyncing = false
        syncProgress = 1
        if newCount > 0 || updatedCount > 0 {
            syncStatus = "\(newCount) new, \(updatedCount) updated"
        } else {
            syncStatus = "Up to date"
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        isSyncing = true
        syncProgress = 0

        let nextPage = currentPage + 1

        let (listingStream, progressStream) = scrapingService.scrapeProgressively(
            page: nextPage,
            source: selectedSource,
            ebayCategoryIds: ebayCategoryStore.enabledCategoryIds,
            craigslistRegions: craigslistRegionStore.enabledRegions,
            craigslistSearchTerms: craigslistRegionStore.enabledSearchTerms
        )

        let progressTask = Task {
            for await progress in progressStream {
                self.syncProgress = progress.fraction
                self.syncStatus = "Page \(nextPage): \(progress.source.displayName) \(progress.completedSteps)/\(progress.totalSteps)"
            }
        }

        var newCount = 0
        for await listing in listingStream {
            let merged = mergeListing(listing)
            if merged == .inserted { newCount += 1 }
            if let store = listingStore {
                _ = try? store.upsertListings([listing])
            }
        }
        reapplyFilters()

        await progressTask.value
        hasMore = newCount > 0
        currentPage = nextPage

        isSyncing = false
        syncProgress = 1
        isLoading = false
    }

    func clearFilters() {
        selectedSource = nil
        searchQuery = ""
        sortOption = .newest
        priceMin = nil
        priceMax = nil
        hasPhotoOnly = false
        hideSold = true
        hideSeen = true
    }

    // MARK: - Merge

    private enum MergeResult {
        case inserted, updated, unchanged
    }

    private func mergeListing(_ listing: Listing) -> MergeResult {
        if let existing = allScrapedListings[listing.id] {
            if existing.contentHash != listing.contentHash {
                allScrapedListings[listing.id] = listing
                return .updated
            }
            return .unchanged
        } else {
            allScrapedListings[listing.id] = listing
            insertionOrder.append(listing.id)
            evictIfNeeded()
            return .inserted
        }
    }

    private func evictIfNeeded() {
        while allScrapedListings.count > Self.maxInMemoryListings, !insertionOrder.isEmpty {
            let oldestId = insertionOrder.removeFirst()
            allScrapedListings.removeValue(forKey: oldestId)
        }
    }

    private func reapplyFilters() {
        let all = Array(allScrapedListings.values)
        listings = ScrapingService.applyFilters(
            to: all,
            source: selectedSource,
            query: searchQuery.isEmpty ? nil : searchQuery,
            priceMin: priceMin,
            priceMax: priceMax,
            hasPhoto: hasPhotoOnly ? true : nil,
            hideSold: hideSold,
            seenIds: hideSeen ? seenIdsSnapshot : nil,
            sort: sortOption.rawValue
        )
    }

    func markAsSeen(_ listingId: String) {
        // Add to in-memory snapshot (won't re-filter, so current list stays stable)
        seenIdsSnapshot.insert(listingId)
        // Persist to SwiftData
        try? listingStore?.markAsSeen(listingIds: [listingId])
    }

}
