import Foundation

/// Orchestrates export → upload → optional webhook.
protocol SyncServiceProtocol {
    func syncNow() async throws
    /// Uploads via a background `URLSession` chain; completion runs when all succeed or any fails.
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
    private let jsonDecoder: () -> JSONDecoder

    private static let syncStatePath = "HealthData/sync_state.json"
    private static let workoutBatchLimit = 50

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
        },
        jsonDecoder: @escaping () -> JSONDecoder = { JSONDecoder() }
    ) {
        self.healthKit = healthKit
        self.nextcloud = nextcloud
        self.webhookClient = webhookClient
        self.clock = clock
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
    }

    func syncNow() async throws {
        guard healthKit.isHealthDataAvailable else {
            throw SyncServiceError.healthDataUnavailable
        }
        try await nextcloud.validateConfiguration()

        let now = clock()
        let encoder = jsonEncoder()
        let decoder = jsonDecoder()

        let remoteState = try await loadRemoteSyncState(decoder: decoder)

        var workoutPaths: [String] = []
        var anchorData: Data? = remoteState?.workoutQueryAnchor.flatMap { Data(base64Encoded: $0) }
        var workoutAnchorBase64: String? = remoteState?.workoutQueryAnchor

        while true {
            let (batch, newAnchorData) = try await healthKit.fetchWorkoutsIncremental(
                anchor: anchorData,
                limit: Self.workoutBatchLimit
            )
            if let newAnchorData {
                workoutAnchorBase64 = newAnchorData.base64EncodedString()
            }
            if batch.isEmpty {
                break
            }
            for input in batch {
                let workout = healthKit.makeWorkoutData(from: input)
                let fileData = try encoder.encode(workout)
                let path = "HealthData/workouts/\(input.date)_\(input.sourceIdentifier).json"
                try await nextcloud.upload(data: fileData, remotePath: path, contentType: "application/json")
                workoutPaths.append(path)
            }
            anchorData = newAnchorData
        }

        let dailyInput = try await healthKit.dailyAggregationInput(for: now)
        let daily = healthKit.makeDailyHealthData(from: dailyInput)
        let dailyData = try encoder.encode(daily)
        let dayKey = dailyInput.date
        let dailyPath = "HealthData/daily/\(dayKey).json"
        try await nextcloud.upload(data: dailyData, remotePath: dailyPath, contentType: "application/json")

        let state = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
            lastDailyExportDate: dayKey,
            workoutQueryAnchor: workoutAnchorBase64,
            notes: remoteState?.notes
        )
        let stateData = try encoder.encode(state)
        try await nextcloud.upload(data: stateData, remotePath: Self.syncStatePath, contentType: "application/json")

        var webhookFiles = workoutPaths
        webhookFiles.append(dailyPath)
        webhookFiles.append(Self.syncStatePath)
        try await webhookClient.postSyncCompleteIfConfigured(date: dayKey, files: webhookFiles)
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
                let encoder = jsonEncoder()
                let decoder = jsonDecoder()

                let remoteState = try await loadRemoteSyncState(decoder: decoder)

                var items: [(Data, String, String)] = []
                var workoutPaths: [String] = []
                var anchorData: Data? = remoteState?.workoutQueryAnchor.flatMap { Data(base64Encoded: $0) }
                var workoutAnchorBase64: String? = remoteState?.workoutQueryAnchor

                while true {
                    let (batch, newAnchorData) = try await healthKit.fetchWorkoutsIncremental(
                        anchor: anchorData,
                        limit: Self.workoutBatchLimit
                    )
                    if let newAnchorData {
                        workoutAnchorBase64 = newAnchorData.base64EncodedString()
                    }
                    if batch.isEmpty {
                        break
                    }
                    for input in batch {
                        let workout = healthKit.makeWorkoutData(from: input)
                        let fileData = try encoder.encode(workout)
                        let path = "HealthData/workouts/\(input.date)_\(input.sourceIdentifier).json"
                        items.append((fileData, path, "application/json"))
                        workoutPaths.append(path)
                    }
                    anchorData = newAnchorData
                }

                let dailyInput = try await healthKit.dailyAggregationInput(for: now)
                let daily = healthKit.makeDailyHealthData(from: dailyInput)
                let dailyData = try encoder.encode(daily)
                let dayKey = dailyInput.date
                let dailyPath = "HealthData/daily/\(dayKey).json"
                items.append((dailyData, dailyPath, "application/json"))

                let state = SyncState(
                    lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
                    lastDailyExportDate: dayKey,
                    workoutQueryAnchor: workoutAnchorBase64,
                    notes: remoteState?.notes
                )
                let stateData = try encoder.encode(state)
                items.append((stateData, Self.syncStatePath, "application/json"))

                try nextcloud.enqueueSequentialBackgroundUploads(
                    items: items.map { (data: $0.0, remotePath: $0.1, contentType: $0.2) },
                    onAllFinished: { uploadResult in
                        Task {
                            do {
                                switch uploadResult {
                                case .success:
                                    var webhookFiles = workoutPaths
                                    webhookFiles.append(dailyPath)
                                    webhookFiles.append(Self.syncStatePath)
                                    try await self.webhookClient.postSyncCompleteIfConfigured(
                                        date: dayKey,
                                        files: webhookFiles
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

    private func loadRemoteSyncState(decoder: JSONDecoder) async throws -> SyncState? {
        guard let data = try await nextcloud.download(remotePath: Self.syncStatePath) else {
            return nil
        }
        return try? decoder.decode(SyncState.self, from: data)
    }
}
