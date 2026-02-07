import Foundation
import UserNotifications

struct NotificationService: Sendable {
    static let categoryIdentifier = "LISTING_ALERT"

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func sendListingAlert(listing: Listing, triggerName: String) async {
        let content = UNMutableNotificationContent()
        content.title = triggerName
        content.body = listing.title
        if let price = listing.formattedPrice {
            content.body += " — \(price)"
        }
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "listingId": listing.id,
            "sourceUrl": listing.sourceUrl,
        ]

        let request = UNNotificationRequest(
            identifier: "alert-\(listing.id)",
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
