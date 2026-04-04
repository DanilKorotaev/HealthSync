import Foundation

/// Central place for non-secret defaults. URLs and secrets must never be hardcoded; use env or user settings.
enum AppConfiguration {
    /// Prefix for `ProcessInfo` environment variables (Xcode scheme, CI).
    static let environmentPrefix = "HEALTHSYNC_"

    enum Keys {
        static let nextcloudBaseURL = "NEXTCLOUD_BASE_URL"
        static let nextcloudWebDAVRoot = "NEXTCLOUD_WEBDAV_ROOT"
        static let syncWebhookURL = "SYNC_WEBHOOK_URL"
        /// Optional Bearer token for `POST` sync webhook (e.g. `health-sync-api`).
        static let syncWebhookToken = "SYNC_WEBHOOK_TOKEN"
    }

    enum UserSettingsKeys {
        static let backgroundSyncNotifications = "healthsync.settings.background_sync_notifications"
        /// When `true`, registers HealthKit observer queries for background sync (default on).
        static let backgroundSyncEnabled = "healthsync.settings.background_sync_enabled"
    }

    static var backgroundSyncNotificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserSettingsKeys.backgroundSyncNotifications)
    }

    static func setBackgroundSyncNotificationsEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: UserSettingsKeys.backgroundSyncNotifications)
    }

    /// User toggle: HealthKit-driven background sync. Default `true` when key is unset.
    static var backgroundSyncEnabled: Bool {
        if UserDefaults.standard.object(forKey: UserSettingsKeys.backgroundSyncEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: UserSettingsKeys.backgroundSyncEnabled)
    }

    static func setBackgroundSyncEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: UserSettingsKeys.backgroundSyncEnabled)
    }

    static func string(for key: String) -> String? {
        let name = environmentPrefix + key
        let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }
        return UserDefaults.standard.string(forKey: userDefaultsKey(for: key))?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    static func url(for key: String) -> URL? {
        guard let raw = string(for: key) else { return nil }
        return URL(string: raw)
    }

    static func setUserString(_ value: String?, for key: String) {
        let udKey = userDefaultsKey(for: key)
        if let value {
            UserDefaults.standard.set(value, forKey: udKey)
        } else {
            UserDefaults.standard.removeObject(forKey: udKey)
        }
    }

    private static func userDefaultsKey(for key: String) -> String {
        "healthsync.config.\(key.lowercased())"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
