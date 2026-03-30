import Foundation
import HealthKit

/// Reads samples from HealthKit (implementation in a later milestone).
final class HealthKitService {
    init() {}

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
}
