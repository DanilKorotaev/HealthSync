import Foundation

/// Orchestrates export → upload → optional webhook.
protocol SyncServiceProtocol {
    func syncNow() async throws
    /// Uploads via a background `URLSession` chain; calls `completion` when uploads (and optional webhook) finish.
    func syncNowUsingBackgroundUploads(completion: @escaping (Result<Void, Error>) -> Void)
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

    func syncNowUsingBackgroundUploads(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                guard healthKit.isHealthDataAvailable else {
                    completion(.failure(SyncServiceError.healthDataUnavailable))
                    return
                }
                try await nextcloud.validateConfiguration()

                let now = clock()
                let input = try await healthKit.dailyAggregationInput(for: now)
                let daily = healthKit.makeDailyHealthData(from: input)
                let encoder = jsonEncoder()
                let dailyData = try encoder.encode(daily)
                let dayKey = CalendarDayFormatter.yyyyMMdd(for: now)
                let dailyPath = "HealthData/daily/\(dayKey).json"

                let state = SyncState(
                    lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
                    lastDailyExportDate: dayKey,
                    notes: nil
                )
                let stateData = try encoder.encode(state)

                try nextcloud.enqueueSequentialBackgroundUploads(
                    items: [
                        (dailyData, dailyPath, "application/json"),
                        (stateData, "HealthData/sync_state.json", "application/json")
                    ],
                    onAllFinished: { uploadResult in
                        Task {
                            do {
                                switch uploadResult {
                                case .success:
                                    try await self.webhookClient.postSyncCompleteIfConfigured(
                                        date: dayKey,
                                        files: [dailyPath, "HealthData/sync_state.json"]
                                    )
                                    completion(.success(()))
                                case let .failure(error):
                                    completion(.failure(error))
                                }
                            } catch {
                                completion(.failure(error))
                            }
                        }
                    }
                )
            } catch {
                completion(.failure(error))
            }
        }
    }
}
