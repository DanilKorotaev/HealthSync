import Foundation

/// Workout export shape (see project documentation for full JSON schema).
struct WorkoutData: Codable, Equatable {
    var date: String
    var workoutType: String
    var syncedAt: String?

    enum CodingKeys: String, CodingKey {
        case date
        case workoutType = "workout_type"
        case syncedAt = "synced_at"
    }
}
