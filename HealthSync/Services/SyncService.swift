import Foundation

/// Orchestrates export → upload → optional webhook (implementation in a later milestone).
protocol SyncServiceProtocol {
    func syncNow() async throws
}

enum SyncServiceError: Error, Equatable {
    case healthDataUnavailable
    case invalidWebhookResponse
    case webhookRejected(statusCode: Int)
}

final class SyncService: SyncServiceProtocol {
    private let healthKit: HealthKitServiceProtocol
    private let nextcloud: NextCloudServiceProtocol
    private let webhookClient: SyncWebhookClientProtocol
    private let clock: () -> Date
    private let jsonEncoder: () -> JSONEncoder

    init(
        healthKit: HealthKitServiceProtocol = HealthKitService(),
        nextcloud: NextCloudServiceProtocol = NextCloudService(),
        webhookClient: SyncWebhookClientProtocol = SyncWebhookClient(),
        clock: @escaping () -> Date = Date.init,
        jsonEncoder: @escaping () -> JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        }
    ) {
        self.healthKit = healthKit
        self.nextcloud = nextcloud
        self.webhookClient = webhookClient
        self.clock = clock
        self.jsonEncoder = jsonEncoder
    }

    func syncNow() async throws {
        guard healthKit.isHealthDataAvailable else {
            throw SyncServiceError.healthDataUnavailable
        }
        try await nextcloud.validateConfiguration()

        let now = clock()
        let input = try await healthKit.dailyAggregationInput(for: now)
        let daily = healthKit.makeDailyHealthData(from: input)
        let encoder = jsonEncoder()
        let dailyData = try encoder.encode(daily)
        let dayKey = CalendarDayFormatter.yyyyMMdd(for: now)
        let dailyPath = "HealthData/daily/\(dayKey).json"
        try await nextcloud.upload(data: dailyData, remotePath: dailyPath, contentType: "application/json")

        let state = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
            lastDailyExportDate: dayKey,
            notes: nil
        )
        let stateData = try encoder.encode(state)
        try await nextcloud.upload(data: stateData, remotePath: "HealthData/sync_state.json", contentType: "application/json")

        try await webhookClient.postSyncCompleteIfConfigured(date: dayKey, files: [dailyPath, "HealthData/sync_state.json"])
    }
}
