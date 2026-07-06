import XCTest
@testable import ScreenTime

final class TimeFormattingTests: XCTestCase {
    func test_zeroSeconds() {
        XCTAssertEqual(TimeFormatting.format(seconds: 0), "0h 0m")
    }

    func test_oneHourOneMinute() {
        XCTAssertEqual(TimeFormatting.format(seconds: 3661), "1h 1m")
    }

    func test_threeHoursFortyTwoMinutes() {
        XCTAssertEqual(TimeFormatting.format(seconds: 13320), "3h 42m")
    }
}
