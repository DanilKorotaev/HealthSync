import Foundation
import HealthKit

/// Reads samples from HealthKit (implementation in a later milestone).
protocol HealthKitServiceProtocol {
    var isHealthDataAvailable: Bool { get }
}

final class HealthKitService: HealthKitServiceProtocol {
    init() {}

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
}
