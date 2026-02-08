import BackgroundTasks
import Foundation
import SwiftData

struct BackgroundRefreshService: Sendable {
    static let taskIdentifier = "com.jsvana.cwswap.refresh"

    /// Minimum interval between background refreshes (30 minutes).
    static let minimumInterval: TimeInterval = 30 * 60

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: .main
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            // Handler runs on main queue (.main above), so MainActor is safe
            nonisolated(unsafe) let task = refreshTask
            MainActor.assumeIsolated {
                handleRefresh(task)
            }
        }
    }

    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private static func handleRefresh(_ task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let refreshTask = Task {
            do {
                try await performRefreshAndNotify()
            } catch {
                // Background refresh failed; next scheduled attempt will retry
            }
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }

        Task {
            _ = await refreshTask.result
            task.setTaskCompleted(success: true)
        }
    }

    @MainActor
    static func performRefreshAndNotify() async throws {
        let container = try ModelContainer(for: PersistedListing.self, TriggerAlert.self)
        let context = container.mainContext

        // Fetch enabled triggers
        let triggerDescriptor = FetchDescriptor<TriggerAlert>(
            predicate: #Predicate { $0.isEnabled == true }
        )
        let triggers = try context.fetch(triggerDescriptor)
        guard !triggers.isEmpty else { return }

        // Scrape latest listings
        let scrapingService = ScrapingService()
        let listings = try await scrapingService.fetchListings(page: 1, hideSold: true)

        // Persist new listings
        let store = ListingStore(modelContext: context)
        try store.upsertListings(listings)

        // Check triggers against listings
        let notificationService = NotificationService()
        for trigger in triggers {
            let alreadyNotified = trigger.notifiedListingIds
            var newlyNotified = alreadyNotified

            for listing in listings {
                guard !alreadyNotified.contains(listing.id) else { continue }
                guard trigger.matches(listing) else { continue }

                await notificationService.sendListingAlert(
                    listing: listing,
                    triggerName: trigger.name
                )
                newlyNotified.insert(listing.id)
                trigger.lastTriggered = Date()
            }

            // Cap stored IDs to prevent unbounded growth (keep last 500)
            if newlyNotified.count > 500 {
                newlyNotified = Set(newlyNotified.suffix(500))
            }
            trigger.notifiedListingIds = newlyNotified
        }

        try context.save()
    }
}
