import XCTest
@testable import HealthSync

final class AppConfigurationTests: XCTestCase {
    func testSetUserStringAndReadBack() {
        let key = "TEST_KEY_\(UUID().uuidString)"
        AppConfiguration.setUserString(" https://example.local ", for: key)

        XCTAssertEqual(AppConfiguration.string(for: key), "https://example.local")
    }

    func testSetUserStringNilRemovesValue() {
        let key = "TEST_KEY_REMOVE_\(UUID().uuidString)"
        AppConfiguration.setUserString("value", for: key)
        AppConfiguration.setUserString(nil, for: key)

        XCTAssertNil(AppConfiguration.string(for: key))
    }
}
