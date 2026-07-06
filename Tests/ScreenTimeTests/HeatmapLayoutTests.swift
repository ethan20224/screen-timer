import XCTest
@testable import ScreenTime

final class HeatmapLayoutTests: XCTestCase {
    func test_weeksForYearPadsLeadingDaysBeforeJan1() {
        // Jan 1, 2026 is a Thursday (Calendar weekday 5, Sunday = 1) -> 4 leading nils.
        let weeks = HeatmapLayout.weeks(forYear: 2026)
        XCTAssertEqual(weeks.first?.count, 7)
        XCTAssertNil(weeks.first?[0])
        XCTAssertNil(weeks.first?[1])
        XCTAssertNil(weeks.first?[2])
        XCTAssertNil(weeks.first?[3])
    }

    func test_weeksForYearContainsAllDays() {
        let weeks = HeatmapLayout.weeks(forYear: 2026)
        let dayCount = weeks.flatMap { $0 }.compactMap { $0 }.count
        XCTAssertEqual(dayCount, 365) // 2026 is not a leap year
    }

    func test_colorForSecondsIncreasesWithMoreTime() {
        let low = HeatmapLayout.color(forSeconds: 0)
        let high = HeatmapLayout.color(forSeconds: 6 * 3600)
        XCTAssertNotEqual(low, high)
    }
}
