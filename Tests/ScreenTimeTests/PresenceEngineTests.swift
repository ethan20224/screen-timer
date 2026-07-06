import XCTest
@testable import ScreenTime

final class PresenceEngineTests: XCTestCase {
    let engine = PresenceEngine(idleThresholdSeconds: 120, tickIntervalSeconds: 15)

    func test_accumulatesWhenActiveAndNotIdle() {
        let state = PresenceEngine.State(currentDay: "2026-07-06", todaySeconds: 0)
        let newState = engine.tick(state: state, todayKey: "2026-07-06", idleSeconds: 5, systemActive: true)
        XCTAssertEqual(newState.todaySeconds, 15)
    }

    func test_doesNotAccumulateWhenIdleOverThreshold() {
        let state = PresenceEngine.State(currentDay: "2026-07-06", todaySeconds: 100)
        let newState = engine.tick(state: state, todayKey: "2026-07-06", idleSeconds: 130, systemActive: true)
        XCTAssertEqual(newState.todaySeconds, 100)
    }

    func test_doesNotAccumulateWhenSystemInactive() {
        let state = PresenceEngine.State(currentDay: "2026-07-06", todaySeconds: 100)
        let newState = engine.tick(state: state, todayKey: "2026-07-06", idleSeconds: 0, systemActive: false)
        XCTAssertEqual(newState.todaySeconds, 100)
    }

    func test_rolloverResetsSecondsThenAccumulates() {
        let state = PresenceEngine.State(currentDay: "2026-07-06", todaySeconds: 500)
        let newState = engine.tick(state: state, todayKey: "2026-07-07", idleSeconds: 0, systemActive: true)
        XCTAssertEqual(newState.currentDay, "2026-07-07")
        XCTAssertEqual(newState.todaySeconds, 15)
    }
}
