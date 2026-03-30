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
        let sut = SyncService(
            healthKit: HealthKitServiceMock(isHealthDataAvailable: true),
            nextcloud: nextcloud
        )

        try await sut.syncNow()
        XCTAssertEqual(nextcloud.validateConfigurationCallCount, 1)
    }
}

private struct HealthKitServiceMock: HealthKitServiceProtocol {
    let isHealthDataAvailable: Bool
    var requiredReadTypes: Set<HKObjectType> { [] }
    func requestReadAuthorization() async throws {}
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

    func validateConfiguration() async throws {
        validateConfigurationCallCount += 1
    }
}
