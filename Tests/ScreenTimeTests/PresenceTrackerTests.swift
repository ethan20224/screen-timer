import XCTest
@testable import ScreenTime

final class PresenceTrackerTests: XCTestCase {
    func makeTempStore() -> ScreenTimeStore {
        let path = NSTemporaryDirectory() + UUID().uuidString + ".sqlite3"
        return try! ScreenTimeStore(path: path)
    }

    func test_tickAccumulatesSecondsWhenActive() {
        let store = makeTempStore()
        let tracker = PresenceTracker(
            store: store,
            tickIntervalSeconds: 15,
            persistEveryTicks: 100,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            idleSecondsProvider: { 0 }
        )
        tracker.tick()
        XCTAssertEqual(tracker.state.todaySeconds, 15)
    }

    func test_tickDoesNotAccumulateWhenIdleOverThreshold() {
        let store = makeTempStore()
        let tracker = PresenceTracker(
            store: store,
            idleThresholdSeconds: 120,
            tickIntervalSeconds: 15,
            persistEveryTicks: 100,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            idleSecondsProvider: { 200 }
        )
        tracker.tick()
        XCTAssertEqual(tracker.state.todaySeconds, 0)
    }

    func test_tickDoesNotAccumulateAfterSystemSleepThenResumesAfterWake() {
        let store = makeTempStore()
        let tracker = PresenceTracker(
            store: store,
            tickIntervalSeconds: 15,
            persistEveryTicks: 100,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            idleSecondsProvider: { 0 }
        )
        tracker.handleSystemSleep()
        tracker.tick()
        XCTAssertEqual(tracker.state.todaySeconds, 0)
        tracker.handleSystemWake()
        tracker.tick()
        XCTAssertEqual(tracker.state.todaySeconds, 15)
    }

    func test_persistsToStoreAfterConfiguredTickCount() {
        let store = makeTempStore()
        let tracker = PresenceTracker(
            store: store,
            tickIntervalSeconds: 15,
            persistEveryTicks: 2,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            idleSecondsProvider: { 0 }
        )
        tracker.tick()
        tracker.tick()
        let today = DayKey.forDate(Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(store.secondsForDay(today), 30)
    }

    func test_dayRolloverFinalizesPreviousDayInStore() {
        let store = makeTempStore()
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let tracker = PresenceTracker(
            store: store,
            tickIntervalSeconds: 15,
            persistEveryTicks: 100,
            clock: { now },
            idleSecondsProvider: { 0 }
        )
        tracker.tick()
        let firstDay = DayKey.forDate(now)
        now = now.addingTimeInterval(60 * 60 * 24)
        tracker.tick()
        XCTAssertEqual(store.secondsForDay(firstDay), 15)
        let secondDay = DayKey.forDate(now)
        XCTAssertEqual(tracker.state.currentDay, secondDay)
        XCTAssertEqual(tracker.state.todaySeconds, 15)
    }
}
