import Foundation

struct PresenceEngine {
    struct State: Equatable {
        var currentDay: String
        var todaySeconds: Int
    }

    let idleThresholdSeconds: TimeInterval
    let tickIntervalSeconds: Int

    func tick(state: State, todayKey: String, idleSeconds: TimeInterval, systemActive: Bool) -> State {
        var newState = state
        if todayKey != state.currentDay {
            newState = State(currentDay: todayKey, todaySeconds: 0)
        }
        if systemActive && idleSeconds < idleThresholdSeconds {
            newState.todaySeconds += tickIntervalSeconds
        }
        return newState
    }
}
