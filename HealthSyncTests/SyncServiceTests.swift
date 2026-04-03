import HealthKit
import XCTest
@testable import HealthSync

final class SyncServiceTests: XCTestCase {
    func testSyncNowThrowsWhenHealthDataUnavailable() async {
        let sut = SyncService(
            healthKit: HealthKitServiceMock(isHealthDataAvailable: false),
            nextcloud: NextCloudServiceMock()
        )

        do {
            try await sut.syncNow()
            XCTFail("Expected syncNow() to throw healthDataUnavailable")
        } catch let error as SyncServiceError {
            XCTAssertEqual(error, .healthDataUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSyncNowValidatesConfigurationWhenHealthDataAvailable() async throws {
        let nextcloud = NextCloudServiceMock()
        let webhook = WebhookMock()
        let sut = SyncService(
            healthKit: HealthKitServiceMock(isHealthDataAvailable: true),
            nextcloud: nextcloud,
            webhookClient: webhook
        )

        try await sut.syncNow()
        XCTAssertEqual(nextcloud.validateConfigurationCallCount, 1)
        XCTAssertEqual(nextcloud.downloadPaths, ["HealthData/sync_state.json"])
        XCTAssertEqual(nextcloud.uploads.count, 2)
        XCTAssertTrue(nextcloud.uploads.contains { $0.path.hasPrefix("HealthData/daily/") && $0.path.hasSuffix(".json") })
        XCTAssertTrue(nextcloud.uploads.contains { $0.path == "HealthData/sync_state.json" })
        XCTAssertEqual(webhook.calls.count, 1)
    }

    func testSyncNowUploadsIncrementalWorkoutThenDailyAndState() async throws {
        let nextcloud = NextCloudServiceMock()
        let webhook = WebhookMock()
        let workout = WorkoutAggregationInput(
            sourceIdentifier: "11111111-1111-1111-1111-111111111111",
            date: "2026-06-01",
            workoutType: "running",
            workoutTypeDisplay: "Running",
            isGym: false,
            durationMinutes: 30,
            distanceKm: 5,
            activeCalories: 200,
            totalCalories: 200,
            heartRateSamples: [],
            linkedNote: nil,
            syncedAt: "2026-06-01T10:00:00Z"
        )
        let healthKit = HealthKitServiceMock(isHealthDataAvailable: true)
        healthKit.incrementalBatches = [
            ([workout], Data([0xAB])),
            ([], nil)
        ]
        let sut = SyncService(
            healthKit: healthKit,
            nextcloud: nextcloud,
            webhookClient: webhook
        )

        try await sut.syncNow()

        XCTAssertEqual(nextcloud.uploads.count, 3)
        let workoutPath = "HealthData/workouts/2026-06-01_11111111-1111-1111-1111-111111111111.json"
        XCTAssertTrue(nextcloud.uploads.contains { $0.path == workoutPath })
        XCTAssertEqual(webhook.calls.first?.files.count, 3)
        XCTAssertTrue(webhook.calls.first?.files.contains(workoutPath) ?? false)
    }

    func testSyncNowUsingBackgroundUploadsCompletesSuccessfully() async {
        let nextcloud = NextCloudServiceMock()
        let webhook = WebhookMock()
        let sut = SyncService(
            healthKit: HealthKitServiceMock(isHealthDataAvailable: true),
            nextcloud: nextcloud,
            webhookClient: webhook
        )

        let exp = expectation(description: "background sync")
        sut.syncNowUsingBackgroundUploads { result in
            if case .success = result {
                exp.fulfill()
            } else {
                XCTFail("Expected success, got \(String(describing: result))")
            }
        }
        await fulfillment(of: [exp], timeout: 3.0)

        XCTAssertEqual(nextcloud.validateConfigurationCallCount, 1)
        XCTAssertEqual(nextcloud.backgroundEnqueueCount, 1)
        XCTAssertEqual(webhook.calls.count, 1)
    }

    func testSyncNowCallsWebhookWithRelativePaths() async throws {
        let nextcloud = NextCloudServiceMock()
        let webhook = WebhookMock()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let fixedDate = formatter.date(from: "2026-06-01T12:00:00Z") else {
            XCTFail("Failed to parse fixed date")
            return
        }
        let sut = SyncService(
            healthKit: HealthKitServiceMock(isHealthDataAvailable: true),
            nextcloud: nextcloud,
            webhookClient: webhook,
            clock: { fixedDate }
        )

        try await sut.syncNow()

        XCTAssertEqual(webhook.calls.count, 1)
        XCTAssertEqual(webhook.calls.first?.date, "2026-06-01")
        XCTAssertEqual(
            Set(webhook.calls.first?.files ?? []),
            ["HealthData/daily/2026-06-01.json", "HealthData/sync_state.json"]
        )
    }
}

private final class HealthKitServiceMock: HealthKitServiceProtocol {
    typealias WorkoutIncrementalBatch = ([WorkoutAggregationInput], Data?)

    let isHealthDataAvailable: Bool
    /// Simulates `HKAnchoredObjectQuery` pages: each tuple is one batch; an empty first array ends the workout phase.
    var incrementalBatches: [WorkoutIncrementalBatch] = [([], nil)]
    private var incrementalIndex = 0

    var requiredReadTypes: Set<HKObjectType> { [] }

    init(isHealthDataAvailable: Bool = true) {
        self.isHealthDataAvailable = isHealthDataAvailable
    }

    func requestReadAuthorization() async throws {}

    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput {
        DailyAggregationInput(
            date: CalendarDayFormatter.yyyyMMdd(for: date),
            steps: 0,
            distanceKm: 0,
            activeCalories: 0,
            basalCalories: 0,
            exerciseMinutes: 0,
            standHours: 0,
            restingHeartRate: nil,
            hrvValues: [],
            oxygenSaturationValues: [],
            heartRateValues: [],
            heartRateSummary: nil,
            sleep: nil,
            syncedAt: "2026-03-31T00:00:00Z"
        )
    }

    func fetchWorkoutsIncremental(anchor: Data?, limit: Int) async throws -> (
        workouts: [WorkoutAggregationInput],
        newAnchor: Data?
    ) {
        guard incrementalIndex < incrementalBatches.count else {
            return (workouts: [], newAnchor: nil)
        }
        let batch = incrementalBatches[incrementalIndex]
        incrementalIndex += 1
        return (workouts: batch.0, newAnchor: batch.1)
    }

    func makeDailyHealthData(from input: DailyAggregationInput) -> DailyHealthData {
        DailyHealthData(
            date: input.date,
            steps: 0,
            distanceKm: 0,
            activeCalories: 0,
            basalCalories: 0,
            totalCalories: 0,
            exerciseMinutes: 0,
            standHours: 0,
            restingHeartRate: nil,
            hrvAverage: nil,
            oxygenSaturationAverage: nil,
            heartRate: nil,
            sleep: nil,
            syncedAt: nil
        )
    }

    func makeWorkoutData(from input: WorkoutAggregationInput) -> WorkoutData {
        WorkoutData(
            sourceIdentifier: input.sourceIdentifier,
            date: input.date,
            workoutType: input.workoutType,
            workoutTypeDisplay: input.workoutTypeDisplay,
            isGym: input.isGym,
            durationMinutes: input.durationMinutes,
            distanceKm: nil,
            activeCalories: nil,
            totalCalories: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            heartRateZones: nil,
            linkedNote: nil,
            syncedAt: nil
        )
    }
}

private final class NextCloudServiceMock: NextCloudServiceProtocol {
    private(set) var validateConfigurationCallCount = 0
    private(set) var downloadPaths: [String] = []
    private(set) var uploads: [(path: String, contentType: String)] = []
    private(set) var backgroundEnqueueCount = 0

    func validateConfiguration() async throws {
        validateConfigurationCallCount += 1
    }

    func saveCredentials(username: String, password: String) throws {}

    func loadCredentials() throws -> NextCloudCredentials? {
        nil
    }

    func download(remotePath: String) async throws -> Data? {
        downloadPaths.append(remotePath)
        return nil
    }

    func upload(data: Data, remotePath: String, contentType: String) async throws {
        uploads.append((remotePath, contentType))
    }

    func enqueueSequentialBackgroundUploads(
        items: [(data: Data, remotePath: String, contentType: String)],
        onAllFinished: @escaping (Result<Void, Error>) -> Void
    ) throws {
        backgroundEnqueueCount += 1
        DispatchQueue.main.async {
            onAllFinished(.success(()))
        }
    }
}

private final class WebhookMock: SyncWebhookClientProtocol {
    private(set) var calls: [(date: String, files: [String])] = []

    func postSyncCompleteIfConfigured(date: String, files: [String]) async throws {
        calls.append((date, files))
    }
}
