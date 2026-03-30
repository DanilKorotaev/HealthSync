import Foundation

/// Daily aggregate export shape (see project documentation for full JSON schema).
struct DailyHealthData: Codable, Equatable {
    var date: String
    var syncedAt: String?

    enum CodingKeys: String, CodingKey {
        case date
        case syncedAt = "synced_at"
    }
}
