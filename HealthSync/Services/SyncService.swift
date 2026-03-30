import Foundation

/// Orchestrates export → upload → optional webhook (implementation in a later milestone).
final class SyncService {
    private let healthKit: HealthKitService
    private let nextcloud: NextCloudService

    init(
        healthKit: HealthKitService = HealthKitService(),
        nextcloud: NextCloudService = NextCloudService()
    ) {
        self.healthKit = healthKit
        self.nextcloud = nextcloud
    }

    func syncNow() async throws {
        _ = healthKit.isHealthDataAvailable
        try await nextcloud.validateConfiguration()
    }
}
