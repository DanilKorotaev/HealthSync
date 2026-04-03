import Foundation
import UserNotifications

protocol LocalNotificationSchedulingProtocol: AnyObject {
    func notifySyncCompletedIfEnabled() async
    func notifySyncFailedIfEnabled(errorDescription: String) async
}

/// Fires local notifications when background sync finishes, if the user enabled them in Settings.
final class LocalNotificationScheduler: LocalNotificationSchedulingProtocol {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func notifySyncCompletedIfEnabled() async {
        guard AppConfiguration.backgroundSyncNotificationsEnabled else { return }
        guard await authorizedForDelivery() else { return }
        let content = UNMutableNotificationContent()
        content.title = "HealthSync"
        content.body = "Background sync finished."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }

    func notifySyncFailedIfEnabled(errorDescription: String) async {
        guard AppConfiguration.backgroundSyncNotificationsEnabled else { return }
        guard await authorizedForDelivery() else { return }
        let content = UNMutableNotificationContent()
        content.title = "HealthSync"
        content.body = "Background sync failed: \(errorDescription)"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }

    private func authorizedForDelivery() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}
