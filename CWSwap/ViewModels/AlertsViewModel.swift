import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class AlertsViewModel {
    private var modelContext: ModelContext?
    private let notificationService = NotificationService()

    var alerts: [TriggerAlert] = []
    var notificationsAuthorized = false

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func load() async {
        notificationsAuthorized = await notificationService.authorizationStatus() == .authorized
        fetchAlerts()
    }

    func requestNotificationPermission() async {
        notificationsAuthorized = await notificationService.requestAuthorization()
    }

    func fetchAlerts() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<TriggerAlert>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        alerts = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addAlert(
        name: String,
        keyword: String,
        category: ListingCategory?,
        source: ListingSource?,
        priceMin: Double?,
        priceMax: Double?
    ) {
        guard let modelContext else { return }
        let alert = TriggerAlert(
            name: name,
            keyword: keyword,
            category: category,
            source: source,
            priceMin: priceMin,
            priceMax: priceMax
        )
        modelContext.insert(alert)
        try? modelContext.save()
        fetchAlerts()

        // Ensure background refresh is scheduled when alerts exist
        BackgroundRefreshService.scheduleNextRefresh()
    }

    func deleteAlert(_ alert: TriggerAlert) {
        guard let modelContext else { return }
        modelContext.delete(alert)
        try? modelContext.save()
        fetchAlerts()
    }

    func toggleAlert(_ alert: TriggerAlert) {
        alert.isEnabled.toggle()
        try? modelContext?.save()
        fetchAlerts()
    }

    func updateAlert(
        _ alert: TriggerAlert,
        name: String,
        keyword: String,
        category: ListingCategory?,
        source: ListingSource?,
        priceMin: Double?,
        priceMax: Double?
    ) {
        alert.name = name
        alert.keyword = keyword
        alert.listingCategory = category
        alert.listingSource = source
        alert.priceMin = priceMin
        alert.priceMax = priceMax
        try? modelContext?.save()
        fetchAlerts()
    }
}
