import Foundation
import HealthKit

protocol HealthKitServiceProtocol {
    var isHealthDataAvailable: Bool { get }
    var requiredReadTypes: Set<HKObjectType> { get }
    func requestReadAuthorization() async throws
    /// Placeholder until anchored queries are implemented; supplies structured input for export.
    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput
    func makeDailyHealthData(from input: DailyAggregationInput) -> DailyHealthData
    func makeWorkoutData(from input: WorkoutAggregationInput) -> WorkoutData
}

enum HealthKitServiceError: Error, Equatable {
    case healthDataUnavailable
    case backgroundDeliveryEnableFailed
}

struct DailyAggregationInput: Equatable {
    var date: String
    var steps: Int
    var distanceKm: Double
    var activeCalories: Double
    var basalCalories: Double
    var exerciseMinutes: Double
    var standHours: Double
    var restingHeartRate: Double?
    var hrvValues: [Double]
    var oxygenSaturationValues: [Double]
    var heartRateValues: [Double]
    var sleep: SleepSummary?
    var syncedAt: String?
}

struct WorkoutAggregationInput: Equatable {
    struct HeartRateSample: Equatable {
        var bpm: Double
        var durationMinutes: Double
    }

    var date: String
    var workoutType: String
    var workoutTypeDisplay: String
    var isGym: Bool
    var durationMinutes: Double
    var distanceKm: Double?
    var activeCalories: Double?
    var totalCalories: Double?
    var heartRateSamples: [HeartRateSample]
    var linkedNote: String?
    var syncedAt: String?
}

protocol HealthStoreProtocol {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws
}

/// HealthKit APIs needed for background delivery and observer queries (same `HKHealthStore` as reads).
protocol HKBackgroundCapableHealthStore: AnyObject, HealthStoreProtocol {
    func enableBackgroundDelivery(for objectType: HKObjectType, frequency: HKUpdateFrequency) async throws
    func execute(query: HKQuery)
    func stop(query: HKQuery)
}

final class HealthStoreAdapter: HKBackgroundCapableHealthStore {
    static let shared = HealthStoreAdapter()

    private let healthStore = HKHealthStore()

    private init() {}

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func enableBackgroundDelivery(for objectType: HKObjectType, frequency: HKUpdateFrequency) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: objectType, frequency: frequency) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitServiceError.backgroundDeliveryEnableFailed)
                }
            }
        }
    }

    func execute(query: HKQuery) {
        healthStore.execute(query)
    }

    func stop(query: HKQuery) {
        healthStore.stop(query)
    }
}

/// Reads samples from HealthKit and manages authorization.
final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore: HealthStoreProtocol

    init(healthStore: HealthStoreProtocol = HealthStoreAdapter.shared) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        healthStore.isHealthDataAvailable
    }

    var requiredReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .appleStandTime),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        ]
        .compactMap { $0 }
        .forEach { types.insert($0) }
        return types
    }

    func requestReadAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }
        try await healthStore.requestAuthorization(toShare: nil, read: requiredReadTypes)
    }

    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput {
        let day = CalendarDayFormatter.yyyyMMdd(for: date)
        let syncedAt = CalendarDayFormatter.iso8601UTCSeconds(from: Date())
        return DailyAggregationInput(
            date: day,
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
            syncedAt: syncedAt
        )
    }

    func makeDailyHealthData(from input: DailyAggregationInput) -> DailyHealthData {
        let heartRateStats: HeartRateStats?
        if !input.heartRateValues.isEmpty {
            heartRateStats = HeartRateStats(
                min: input.heartRateValues.min() ?? 0,
                max: input.heartRateValues.max() ?? 0,
                average: input.heartRateValues.average
            )
        } else {
            heartRateStats = nil
        }

        return DailyHealthData(
            date: input.date,
            steps: input.steps,
            distanceKm: input.distanceKm,
            activeCalories: input.activeCalories,
            basalCalories: input.basalCalories,
            totalCalories: input.activeCalories + input.basalCalories,
            exerciseMinutes: input.exerciseMinutes,
            standHours: input.standHours,
            restingHeartRate: input.restingHeartRate,
            hrvAverage: input.hrvValues.averageOrNil,
            oxygenSaturationAverage: input.oxygenSaturationValues.averageOrNil,
            heartRate: heartRateStats,
            sleep: input.sleep,
            syncedAt: input.syncedAt
        )
    }

    func makeWorkoutData(from input: WorkoutAggregationInput) -> WorkoutData {
        let averageHeartRate = input.heartRateSamples.isEmpty ? nil : input.heartRateSamples.map(\.bpm).average
        let maxHeartRate = input.heartRateSamples.map(\.bpm).max()
        let zones = makeHeartRateZones(from: input.heartRateSamples)

        return WorkoutData(
            date: input.date,
            workoutType: input.workoutType,
            workoutTypeDisplay: input.workoutTypeDisplay,
            isGym: input.isGym,
            durationMinutes: input.durationMinutes,
            distanceKm: input.distanceKm,
            activeCalories: input.activeCalories,
            totalCalories: input.totalCalories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateZones: zones,
            linkedNote: input.linkedNote,
            syncedAt: input.syncedAt
        )
    }

    private func makeHeartRateZones(from samples: [WorkoutAggregationInput.HeartRateSample]) -> HeartRateZones? {
        guard !samples.isEmpty else { return nil }
        let maxObserved = max(samples.map(\.bpm).max() ?? 0, 1)
        var zone1 = 0.0
        var zone2 = 0.0
        var zone3 = 0.0
        var zone4 = 0.0
        var zone5 = 0.0

        for sample in samples {
            let percent = sample.bpm / maxObserved
            switch percent {
            case ..<0.6:
                zone1 += sample.durationMinutes
            case ..<0.7:
                zone2 += sample.durationMinutes
            case ..<0.8:
                zone3 += sample.durationMinutes
            case ..<0.9:
                zone4 += sample.durationMinutes
            default:
                zone5 += sample.durationMinutes
            }
        }

        return HeartRateZones(
            zone1Below60: zone1,
            zone2From60To70: zone2,
            zone3From70To80: zone3,
            zone4From80To90: zone4,
            zone5Above90: zone5
        )
    }
}

private extension Array where Element == Double {
    var averageOrNil: Double? {
        isEmpty ? nil : average
    }

    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
