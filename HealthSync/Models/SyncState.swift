import Foundation

/// Remote `HealthData/sync_state.json` shape (extend when anchors are added).
struct SyncState: Codable, Equatable {
    var lastSyncedAt: String?
    var lastDailyExportDate: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case lastSyncedAt = "last_synced_at"
        case lastDailyExportDate = "last_daily_export_date"
        case notes
    }
}
