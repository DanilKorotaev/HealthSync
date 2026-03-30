import Foundation

/// Persisted sync cursor state (placeholder; extend per HealthKit anchor storage plan).
struct SyncState: Codable, Equatable {
    var lastSyncedAt: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case lastSyncedAt = "last_synced_at"
        case notes
    }
}
