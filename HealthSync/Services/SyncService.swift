import Foundation

/// Orchestrates export → upload → optional webhook (implementation in a later milestone).
protocol SyncServiceProtocol {
    func syncNow() async throws
}

enum SyncServiceError: Error, Equatable {
    case healthDataUnavailable
}

final class SyncService: SyncServiceProtocol {
    private let healthKit: HealthKitServiceProtocol
    private let nextcloud: NextCloudServiceProtocol

    init(
        healthKit: HealthKitServiceProtocol = HealthKitService(),
        nextcloud: NextCloudServiceProtocol = NextCloudService()
    ) {
        self.healthKit = healthKit
        self.nextcloud = nextcloud
    }

    func syncNow() async throws {
        guard healthKit.isHealthDataAvailable else {
            throw SyncServiceError.healthDataUnavailable
        }
        try await nextcloud.validateConfiguration()
    }
}
