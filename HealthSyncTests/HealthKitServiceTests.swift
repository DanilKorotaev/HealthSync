import XCTest
import HealthKit
@testable import HealthSync

final class HealthKitServiceTests: XCTestCase {
    func testRequiredReadTypesContainsCoreIdentifiers() {
        let sut = HealthKitService(healthStore: HealthStoreMock())

        XCTAssertTrue(sut.requiredReadTypes.contains(HKObjectType.workoutType()))
        XCTAssertTrue(sut.requiredReadTypes.contains(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!))
        XCTAssertTrue(sut.requiredReadTypes.contains(HKObjectType.quantityType(forIdentifier: .stepCount)!))
        XCTAssertTrue(sut.requiredReadTypes.contains(HKObjectType.quantityType(forIdentifier: .heartRate)!))
        XCTAssertTrue(sut.requiredReadTypes.contains(HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!))
        XCTAssertTrue(sut.requiredReadTypes.contains(HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!))
    }

    func testRequestReadAuthorizationThrowsWhenHealthDataUnavailable() async {
        let sut = HealthKitService(healthStore: HealthStoreMock(isHealthDataAvailable: false))

        do {
            try await sut.requestReadAuthorization()
            XCTFail("Expected to throw healthDataUnavailable")
        } catch let error as HealthKitServiceError {
            XCTAssertEqual(error, .healthDataUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDailyAggregationInputStubMatchesCalendarDay() async throws {
        let sut = HealthKitService(healthStore: HealthStoreMock())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let date = try XCTUnwrap(formatter.date(from: "2026-04-10T15:00:00Z"))
        let input = try await sut.dailyAggregationInput(for: date)
        XCTAssertEqual(input.date, "2026-04-10")
        XCTAssertNotNil(input.syncedAt)
    }

    func testRequestReadAuthorizationRequestsExpectedTypes() async throws {
        let store = HealthStoreMock(isHealthDataAvailable: true)
        let sut = HealthKitService(healthStore: store)

        try await sut.requestReadAuthorization()

        XCTAssertEqual(store.requestAuthorizationCallCount, 1)
        XCTAssertEqual(store.lastRequestedReadTypes, sut.requiredReadTypes)
    }

    func testMakeDailyHealthDataCalculatesDerivedFields() {
        let sut = HealthKitService(healthStore: HealthStoreMock())
        let input = DailyAggregationInput(
            date: "2026-03-30",
            steps: 8000,
            distanceKm: 6.1,
            activeCalories: 450,
            basalCalories: 1600,
            exerciseMinutes: 70,
            standHours: 12,
            restingHeartRate: 58,
            hrvValues: [40, 50],
            oxygenSaturationValues: [96, 98],
            heartRateValues: [60, 90, 120],
            sleep: SleepSummary(totalMinutes: 420, deepMinutes: 90, remMinutes: 100, lightMinutes: 180, awakeMinutes: 50),
            syncedAt: "2026-03-30T10:00:00Z"
        )

        let result = sut.makeDailyHealthData(from: input)

        XCTAssertEqual(result.totalCalories, 2050)
        XCTAssertEqual(result.hrvAverage, 45)
        XCTAssertEqual(result.oxygenSaturationAverage, 97)
        XCTAssertEqual(result.heartRate?.min, 60)
        XCTAssertEqual(result.heartRate?.max, 120)
        XCTAssertEqual(result.heartRate?.average, 90)
    }

    func testMakeWorkoutDataCalculatesHeartRateAndZones() {
        let sut = HealthKitService(healthStore: HealthStoreMock())
        let input = WorkoutAggregationInput(
            date: "2026-03-30",
            workoutType: "traditional_strength_training",
            workoutTypeDisplay: "Strength",
            isGym: true,
            durationMinutes: 60,
            distanceKm: nil,
            activeCalories: 300,
            totalCalories: 420,
            heartRateSamples: [
                .init(bpm: 90, durationMinutes: 10),   // 60%
                .init(bpm: 105, durationMinutes: 15),  // 70%
                .init(bpm: 120, durationMinutes: 20),  // 80%
                .init(bpm: 135, durationMinutes: 10),  // 90%
                .init(bpm: 150, durationMinutes: 5)    // 100%
            ],
            linkedNote: nil,
            syncedAt: "2026-03-30T10:00:00Z"
        )

        let result = sut.makeWorkoutData(from: input)

        XCTAssertEqual(result.averageHeartRate, 120)
        XCTAssertEqual(result.maxHeartRate, 150)
        XCTAssertEqual(result.heartRateZones?.zone1Below60, 0)
        XCTAssertEqual(result.heartRateZones?.zone2From60To70, 10)
        XCTAssertEqual(result.heartRateZones?.zone3From70To80, 15)
        XCTAssertEqual(result.heartRateZones?.zone4From80To90, 20)
        XCTAssertEqual(result.heartRateZones?.zone5Above90, 15)
    }
}

private final class HealthStoreMock: HealthStoreProtocol {
    private let available: Bool
    private(set) var requestAuthorizationCallCount = 0
    private(set) var lastRequestedReadTypes: Set<HKObjectType>?

    init(isHealthDataAvailable: Bool = true) {
        self.available = isHealthDataAvailable
    }

    var isHealthDataAvailable: Bool {
        available
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws {
        requestAuthorizationCallCount += 1
        lastRequestedReadTypes = typesToRead
    }
}
