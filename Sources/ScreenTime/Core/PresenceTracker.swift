import Foundation
import CoreGraphics
import AppKit

final class PresenceTracker: ObservableObject {
    @Published private(set) var state: PresenceEngine.State

    let store: ScreenTimeStore
    private let engine: PresenceEngine
    private let idleSecondsProvider: () -> TimeInterval
    private let clock: () -> Date
    private var systemActive = true
    private var ticksSincePersist = 0
    private let persistEveryTicks: Int
    private var timer: Timer?

    init(
        store: ScreenTimeStore,
        idleThresholdSeconds: TimeInterval = 120,
        tickIntervalSeconds: Int = 15,
        persistEveryTicks: Int = 2,
        clock: @escaping () -> Date = Date.init,
        idleSecondsProvider: @escaping () -> TimeInterval = {
            // kCGAnyInputEventType — time since ANY input (key/mouse). `.null` never fires,
            // so it returned an ever-growing value and every tick looked idle.
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        }
    ) {
        self.store = store
        self.engine = PresenceEngine(idleThresholdSeconds: idleThresholdSeconds, tickIntervalSeconds: tickIntervalSeconds)
        self.clock = clock
        self.idleSecondsProvider = idleSecondsProvider
        self.persistEveryTicks = persistEveryTicks
        let today = DayKey.forDate(clock())
        self.state = PresenceEngine.State(currentDay: today, todaySeconds: store.secondsForDay(today))
    }

    func start() {
        observeWorkspaceNotifications()
        timer = Timer.scheduledTimer(withTimeInterval: Double(engine.tickIntervalSeconds), repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func tick() {
        let now = clock()
        let todayKey = DayKey.forDate(now)
        let previousDay = state.currentDay
        let idle = idleSecondsProvider()
        let newState = engine.tick(state: state, todayKey: todayKey, idleSeconds: idle, systemActive: systemActive)
        if todayKey != previousDay {
            store.save(day: previousDay, seconds: state.todaySeconds)
        }
        state = newState
        ticksSincePersist += 1
        if ticksSincePersist >= persistEveryTicks {
            store.save(day: state.currentDay, seconds: state.todaySeconds)
            ticksSincePersist = 0
        }
    }

    func handleSystemSleep() { systemActive = false }
    func handleSystemWake() { systemActive = true }

    private func observeWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSystemSleep()
        }
        center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSystemWake()
        }
        center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSystemSleep()
        }
        center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSystemWake()
        }
    }
}
