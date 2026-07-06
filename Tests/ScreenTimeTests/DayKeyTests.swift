import XCTest
@testable import ScreenTime

final class DayKeyTests: XCTestCase {
    func test_forDateFormatsAsYearMonthDayInUTC() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
        XCTAssertEqual(DayKey.forDate(date, timeZone: TimeZone(identifier: "UTC")!), "2023-11-14")
    }
}
