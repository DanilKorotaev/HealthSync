import HealthKit
import XCTest
@testable import HealthSync

final class BackgroundSyncCoordinatorTests: XCTestCase {
    func testStartIfNeededInvokesRegistrarWhenHealthAvailable() async {
        let exp = expectation(description: "observe")
        let mock = RegistrarMock {
            exp.fulfill()
        }
        let coordinator = BackgroundSyncCoordinator(
            registrar: mock,
            syncService: SyncServiceNeverCalled(),
            notificationScheduler: NotificationSchedulerMock(),
            isHealthDataAvailable: { true },
            isBackgroundSyncEnabled: { true },
            sampleTypesProvider: { [] }
        )

        coordinator.syncWithUserPreference()
        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertEqual(mock.startObservingCallCount, 1)
    }

    func testStartIfNeededSkippedWhenHealthUnavailable() async {
        let mock = RegistrarMock()
        let coordinator = BackgroundSyncCoordinator(
            registrar: mock,
            syncService: SyncServiceNeverCalled(),
            notificationScheduler: NotificationSchedulerMock(),
            isHealthDataAvailable: { false },
            isBackgroundSyncEnabled: { true },
            sampleTypesProvider: { [] }
        )

        coordinator.syncWithUserPreference()
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mock.startObservingCallCount, 0)
    }

    func testStartIfNeededOnlyCallsRegistrarOnce() async {
        let mock = RegistrarMock()
        let coordinator = BackgroundSyncCoordinator(
            registrar: mock,
            syncService: SyncServiceNeverCalled(),
            notificationScheduler: NotificationSchedulerMock(),
            isHealthDataAvailable: { true },
            isBackgroundSyncEnabled: { true },
            sampleTypesProvider: { [] }
        )

        coordinator.syncWithUserPreference()
        coordinator.syncWithUserPreference()
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mock.startObservingCallCount, 1)
    }

    func testSyncSkippedWhenBackgroundSyncDisabled() async {
        let mock = RegistrarMock()
        let coordinator = BackgroundSyncCoordinator(
            registrar: mock,
            syncService: SyncServiceNeverCalled(),
            notificationScheduler: NotificationSchedulerMock(),
            isHealthDataAvailable: { true },
            isBackgroundSyncEnabled: { false },
            sampleTypesProvider: { [] }
        )

        coordinator.syncWithUserPreference()
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mock.startObservingCallCount, 0)
    }
}

private final class RegistrarMock: HealthKitBackgroundObserverRegistrarProtocol {
    private(set) var startObservingCallCount = 0
    private let onStarted: (() -> Void)?

    init(onStarted: (() -> Void)? = nil) {
        self.onStarted = onStarted
    }

    func startObserving(
        sampleTypes: [HKSampleType],
        onUpdates: @escaping (@escaping () -> Void) -> Void
    ) async throws {
        startObservingCallCount += 1
        onStarted?()
    }

    func stopObserving() async {}
}

private final class SyncServiceNeverCalled: SyncServiceProtocol {
    func syncNow() async throws {
        XCTFail("unexpected syncNow")
    }

    func syncNowUsingBackgroundUploads(completion: @escaping (Result<Void, Error>) -> Void) {
        XCTFail("unexpected syncNowUsingBackgroundUploads")
    }
}

private final class NotificationSchedulerMock: LocalNotificationSchedulingProtocol {
    func notifySyncCompletedIfEnabled() async {}
    func notifySyncFailedIfEnabled(errorDescription: String) async {}
}
