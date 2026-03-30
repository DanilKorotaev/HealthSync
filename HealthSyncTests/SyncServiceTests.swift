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
        XCTAssertEqual(nextcloud.uploads.count, 2)
        XCTAssertTrue(nextcloud.uploads.contains { $0.path.hasPrefix("HealthData/daily/") && $0.path.hasSuffix(".json") })
        XCTAssertTrue(nextcloud.uploads.contains { $0.path == "HealthData/sync_state.json" })
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

private struct HealthKitServiceMock: HealthKitServiceProtocol {
    let isHealthDataAvailable: Bool
    var requiredReadTypes: Set<HKObjectType> { [] }
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
            sleep: nil,
            syncedAt: "2026-03-31T00:00:00Z"
        )
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
    private(set) var uploads: [(path: String, contentType: String)] = []

    func validateConfiguration() async throws {
        validateConfigurationCallCount += 1
    }

    func saveCredentials(username: String, password: String) throws {}

    func loadCredentials() throws -> NextCloudCredentials? {
        nil
    }

    func upload(data: Data, remotePath: String, contentType: String) async throws {
        uploads.append((remotePath, contentType))
    }
}

private final class WebhookMock: SyncWebhookClientProtocol {
    private(set) var calls: [(date: String, files: [String])] = []

    func postSyncCompleteIfConfigured(date: String, files: [String]) async throws {
        calls.append((date, files))
    }
}
