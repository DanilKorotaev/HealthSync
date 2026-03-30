import XCTest
@testable import HealthSync

final class CalendarDayFormatterTests: XCTestCase {
    func testYyyyMMddUsesUTC() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 3
        components.day = 31
        components.hour = 22
        let date = components.date!
        XCTAssertEqual(CalendarDayFormatter.yyyyMMdd(for: date), "2026-03-31")
    }
}
