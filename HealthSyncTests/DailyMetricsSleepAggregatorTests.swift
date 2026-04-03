import HealthKit
import XCTest
@testable import HealthSync

final class DailyMetricsSleepAggregatorTests: XCTestCase {
    func testBuildSummaryAggregatesStageInsideDay() throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            XCTFail("Missing sleep type")
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 0, minute: 0))!
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let segmentStart = cal.date(byAdding: .hour, value: 10, to: dayStart)!
        let segmentEnd = cal.date(byAdding: .hour, value: 11, to: dayStart)!

        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            start: segmentStart,
            end: segmentEnd,
            metadata: nil
        )

        let summary = try XCTUnwrap(
            DailyMetricsSleepAggregator.buildSummary(
                categorySamples: [sample],
                dayStart: dayStart,
                dayEnd: dayEnd
            )
        )

        XCTAssertEqual(summary.remMinutes ?? 0, 60, accuracy: 0.01)
        XCTAssertEqual(summary.totalMinutes, 60, accuracy: 0.01)
    }

    func testBuildSummaryClipsSegmentCrossingMidnight() throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            XCTFail("Missing sleep type")
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let longStart = cal.date(byAdding: .hour, value: -2, to: dayStart)!
        let longEnd = cal.date(byAdding: .hour, value: 4, to: dayStart)!

        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            start: longStart,
            end: longEnd,
            metadata: nil
        )

        let summary = try XCTUnwrap(
            DailyMetricsSleepAggregator.buildSummary(
                categorySamples: [sample],
                dayStart: dayStart,
                dayEnd: dayEnd
            )
        )

        XCTAssertEqual(summary.deepMinutes ?? 0, 4 * 60, accuracy: 0.01)
    }

    func testBuildSummaryReturnsNilWhenNoOverlap() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            XCTFail("Missing sleep type")
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let otherDay = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let otherEnd = cal.date(byAdding: .hour, value: 1, to: otherDay)!

        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            start: otherDay,
            end: otherEnd,
            metadata: nil
        )

        let summary = DailyMetricsSleepAggregator.buildSummary(
            categorySamples: [sample],
            dayStart: dayStart,
            dayEnd: dayEnd
        )

        XCTAssertNil(summary)
    }
}
