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
}

private final class NextCloudServiceMock: NextCloudServiceProtocol {
    private(set) var validateConfigurationCallCount = 0

    func validateConfiguration() async throws {
        validateConfigurationCallCount += 1
    }
}
