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
    private let calendar: Calendar
    /// How far back (in calendar days from today) daily JSON backfill may run.
    private let dailyBackfillMaxAgeDays: Int
    /// How many past `HealthData/daily/*.json` files to upload per sync; `0` disables backfill.
    private let dailyBackfillBatchSize: Int

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
        jsonDecoder: @escaping () -> JSONDecoder = { JSONDecoder() },
        calendar: Calendar = .current,
        dailyBackfillMaxAgeDays: Int = 730,
        dailyBackfillBatchSize: Int = 7
    ) {
        self.healthKit = healthKit
        self.nextcloud = nextcloud
        self.webhookClient = webhookClient
        self.clock = clock
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
        self.calendar = calendar
        self.dailyBackfillMaxAgeDays = dailyBackfillMaxAgeDays
        self.dailyBackfillBatchSize = dailyBackfillBatchSize
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

        var dailyBackfillOldest = remoteState?.dailyBackfillOldestCompleted
        var backfillPaths: [String] = []
        if dailyBackfillBatchSize > 0 {
            let result = try await dailyBackfillEntries(
                now: now,
                encoder: encoder,
                remoteState: remoteState,
                startingMergedOldest: dailyBackfillOldest
            )
            backfillPaths = result.paths
            for payload in result.payloads {
                try await nextcloud.upload(data: payload.data, remotePath: payload.path, contentType: "application/json")
            }
            dailyBackfillOldest = result.mergedOldestCompleted
        }

        let state = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
            lastDailyExportDate: dayKey,
            workoutQueryAnchor: workoutAnchorBase64,
            dailyBackfillOldestCompleted: dailyBackfillOldest,
            notes: remoteState?.notes
        )
        let stateData = try encoder.encode(state)
        try await nextcloud.upload(data: stateData, remotePath: Self.syncStatePath, contentType: "application/json")

        try await webhookClient.postSyncCompleteIfConfigured(
            date: dayKey,
            files: Self.webhookFileList(workoutPaths: workoutPaths, dailyPath: dailyPath, backfillPaths: backfillPaths)
        )
        SyncRunStore.recordSuccess(at: clock())
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

                var dailyBackfillOldest = remoteState?.dailyBackfillOldestCompleted
                var backfillPaths: [String] = []
                if dailyBackfillBatchSize > 0 {
                    let result = try await dailyBackfillEntries(
                        now: now,
                        encoder: encoder,
                        remoteState: remoteState,
                        startingMergedOldest: dailyBackfillOldest
                    )
                    backfillPaths = result.paths
                    dailyBackfillOldest = result.mergedOldestCompleted
                    for payload in result.payloads {
                        items.append((payload.data, payload.path, "application/json"))
                    }
                }

                let state = SyncState(
                    lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
                    lastDailyExportDate: dayKey,
                    workoutQueryAnchor: workoutAnchorBase64,
                    dailyBackfillOldestCompleted: dailyBackfillOldest,
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
                                    try await self.webhookClient.postSyncCompleteIfConfigured(
                                        date: dayKey,
                                        files: Self.webhookFileList(
                                            workoutPaths: workoutPaths,
                                            dailyPath: dailyPath,
                                            backfillPaths: backfillPaths
                                        )
                                    )
                                    SyncRunStore.recordSuccess(at: self.clock())
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

    /// Same order as upload: workouts → today’s daily → backfill dailies → `sync_state`.
    private static func webhookFileList(workoutPaths: [String], dailyPath: String, backfillPaths: [String]) -> [String] {
        var files = workoutPaths
        files.append(dailyPath)
        files.append(contentsOf: backfillPaths)
        files.append(Self.syncStatePath)
        return files
    }

    private struct DailyBackfillPayload {
        let data: Data
        let path: String
    }

    private func dailyBackfillEntries(
        now: Date,
        encoder: JSONEncoder,
        remoteState: SyncState?,
        startingMergedOldest: String?
    ) async throws -> (paths: [String], payloads: [DailyBackfillPayload], mergedOldestCompleted: String?) {
        let todayStart = calendar.startOfDay(for: now)
        guard let minDate = calendar.date(byAdding: .day, value: -dailyBackfillMaxAgeDays, to: todayStart),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return ([], [], startingMergedOldest)
        }

        let startCursor: Date
        if let oldestStr = remoteState?.dailyBackfillOldestCompleted,
           let oldestDay = CalendarDayFormatter.startOfDay(fromYyyyMMdd: oldestStr, calendar: calendar) {
            let oldestStart = calendar.startOfDay(for: oldestDay)
            startCursor = calendar.date(byAdding: .day, value: -1, to: oldestStart) ?? oldestStart
        } else {
            startCursor = calendar.startOfDay(for: yesterday)
        }

        var cursor = startCursor
        var paths: [String] = []
        var payloads: [DailyBackfillPayload] = []
        var mergedOldest = startingMergedOldest
        var uploadCount = 0

        while uploadCount < dailyBackfillBatchSize {
            if cursor < minDate {
                break
            }
            let input = try await healthKit.dailyAggregationInput(for: cursor)
            let daily = healthKit.makeDailyHealthData(from: input)
            let data = try encoder.encode(daily)
            let path = "HealthData/daily/\(input.date).json"
            paths.append(path)
            payloads.append(DailyBackfillPayload(data: data, path: path))
            mergedOldest = [mergedOldest, input.date].compactMap { $0 }.min()
            uploadCount += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = prev
        }

        return (paths, payloads, mergedOldest)
    }

    private func loadRemoteSyncState(decoder: JSONDecoder) async throws -> SyncState? {
        guard let data = try await nextcloud.download(remotePath: Self.syncStatePath) else {
            return nil
        }
        return try? decoder.decode(SyncState.self, from: data)
    }
}
