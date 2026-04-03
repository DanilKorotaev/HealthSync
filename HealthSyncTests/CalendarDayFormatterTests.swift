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

    func testYyyyMMddLocalDayMatchesCalendarStartOfDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = cal.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 23, minute: 0))!
        XCTAssertEqual(CalendarDayFormatter.yyyyMMddLocalDay(containing: date, calendar: cal), "2026-06-01")
    }
}
