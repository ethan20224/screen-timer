import XCTest
@testable import ScreenTime

final class ScreenTimeStoreTests: XCTestCase {
    func makeTempPath() -> String {
        NSTemporaryDirectory() + UUID().uuidString + ".sqlite3"
    }

    func test_saveAndReadRoundTrip() throws {
        let store = try ScreenTimeStore(path: makeTempPath())
        store.save(day: "2026-07-06", seconds: 3600)
        XCTAssertEqual(store.secondsForDay("2026-07-06"), 3600)
    }

    func test_saveOverwritesExistingDay() throws {
        let store = try ScreenTimeStore(path: makeTempPath())
        store.save(day: "2026-07-06", seconds: 100)
        store.save(day: "2026-07-06", seconds: 200)
        XCTAssertEqual(store.secondsForDay("2026-07-06"), 200)
    }

    func test_secondsForDayReturnsZeroWhenMissing() throws {
        let store = try ScreenTimeStore(path: makeTempPath())
        XCTAssertEqual(store.secondsForDay("2099-01-01"), 0)
    }

    func test_allDaysReturnsEveryStoredDay() throws {
        let store = try ScreenTimeStore(path: makeTempPath())
        store.save(day: "2026-07-01", seconds: 100)
        store.save(day: "2026-07-02", seconds: 200)
        let all = store.allDays()
        XCTAssertEqual(all["2026-07-01"], 100)
        XCTAssertEqual(all["2026-07-02"], 200)
        XCTAssertEqual(all.count, 2)
    }
}
