# ScreenTime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that tracks real active-use screen time (not "laptop powered on" time), shown live in the menu bar and an optional floating widget, with a year-long calendar heatmap history.

**Architecture:** Swift Package Manager executable target (no Xcode project needed). A pure state-machine (`PresenceEngine`) decides active/inactive per tick; a thin OS-facing shell (`PresenceTracker`) feeds it real idle-time/sleep-state signals and persists to a local SQLite file. SwiftUI `MenuBarExtra` + a hand-rolled `NSPanel` widget + a `Window` scene render the UI with Liquid Glass materials.

**Tech Stack:** Swift 5.10+, SwiftUI, AppKit (NSPanel), CoreGraphics (`CGEventSource`), SQLite3 (system library, no external package), `ServiceManagement` (`SMAppService`), XCTest. Target: macOS 26 (Tahoe) only.

## Global Constraints

- Local-only, single Mac, no network calls, no cloud sync (v1).
- Total active seconds per day only — no per-app tracking.
- No camera/audio-based presence detection.
- Idle threshold: 2 minutes (120s) of no keyboard/mouse input → stop counting.
- Screen lock or system sleep → stop counting immediately, regardless of idle timer.
- Tick interval: 15 seconds. Persist to disk at least every 30 seconds (every 2 ticks).
- Day boundary: local midnight, local time zone.
- Target macOS 26 (Tahoe)+, SwiftUI Liquid Glass material (`.glassEffect`) for all panel/widget backgrounds.
- No external Swift packages — SQLite via system `libsqlite3` only.

---

### Task 1: Project scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/ScreenTime/ScreenTimeApp.swift`

**Interfaces:**
- Produces: a buildable/runnable executable target named `ScreenTime`, replaced piece by piece in later tasks. `ScreenTimeApp.swift` is fully rewritten in Task 8 — this version is a throwaway smoke test.

- [ ] **Step 1: Create the package manifest**

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ScreenTime",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenTime",
            path: "Sources/ScreenTime",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "ScreenTimeTests",
            dependencies: ["ScreenTime"],
            path: "Tests/ScreenTimeTests"
        )
    ]
)
```

Note: `.macOS(.v14)` is the safe minimum that compiles on any recent toolchain. Once you open this in a macOS-26-era Xcode, check whether `SupportedPlatform.MacOSVersion` offers a higher case matching Tahoe (autocomplete after `.v` inside `.macOS(...)`) — if so, bump to that case. This matters because `.glassEffect()` (Task 8+) is a macOS-26-only API and needs the deployment target to match or every call site needs an explicit `@available` check.

- [ ] **Step 2: Write a minimal smoke-test app**

```swift
import SwiftUI

@main
struct ScreenTimeApp: App {
    var body: some Scene {
        MenuBarExtra("ScreenTime", systemImage: "clock") {
            Text("Hello, ScreenTime")
        }
    }
}
```

- [ ] **Step 3: Build and run**

Run: `swift build`
Expected: builds with no errors.

Run: `swift run`
Expected: a clock icon appears in the menu bar. Clicking it shows a dropdown with "Hello, ScreenTime". Quit with Ctrl+C in the terminal.

- [ ] **Step 4: Commit**

```bash
git init
git add Package.swift Sources/ScreenTime/ScreenTimeApp.swift
git commit -m "chore: scaffold ScreenTime SwiftPM executable"
```

---

### Task 2: Time formatting

**Files:**
- Create: `Sources/ScreenTime/Core/TimeFormatting.swift`
- Test: `Tests/ScreenTimeTests/TimeFormattingTests.swift`

**Interfaces:**
- Produces: `TimeFormatting.format(seconds: Int) -> String` — used by Task 8, 9, 10 UI views.

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter TimeFormattingTests`
Expected: FAIL — `TimeFormatting` does not exist.

- [ ] **Step 3: Implement**

```swift
enum TimeFormatting {
    static func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter TimeFormattingTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/ScreenTime/Core/TimeFormatting.swift Tests/ScreenTimeTests/TimeFormattingTests.swift
git commit -m "feat: add time formatting helper"
```

---

### Task 3: Presence engine + day key (pure logic)

**Files:**
- Create: `Sources/ScreenTime/Core/PresenceEngine.swift`
- Create: `Sources/ScreenTime/Core/DayKey.swift`
- Test: `Tests/ScreenTimeTests/PresenceEngineTests.swift`
- Test: `Tests/ScreenTimeTests/DayKeyTests.swift`

**Interfaces:**
- Produces: `PresenceEngine.State { currentDay: String, todaySeconds: Int }` (Equatable), `PresenceEngine(idleThresholdSeconds:tickIntervalSeconds:)`, `.tick(state:todayKey:idleSeconds:systemActive:) -> State`. `DayKey.forDate(_:timeZone:) -> String`. Used by Task 5 (`PresenceTracker`) and Task 6 (`HeatmapLayout`).

- [ ] **Step 1: Write failing tests for DayKey**

```swift
import XCTest
@testable import ScreenTime

final class DayKeyTests: XCTestCase {
    func test_forDateFormatsAsYearMonthDayInUTC() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
        XCTAssertEqual(DayKey.forDate(date, timeZone: TimeZone(identifier: "UTC")!), "2023-11-14")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter DayKeyTests`
Expected: FAIL — `DayKey` does not exist.

- [ ] **Step 3: Implement DayKey**

```swift
import Foundation

enum DayKey {
    static func forDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter DayKeyTests`
Expected: PASS.

- [ ] **Step 5: Write failing tests for PresenceEngine**

```swift
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
```

- [ ] **Step 6: Run to verify failure**

Run: `swift test --filter PresenceEngineTests`
Expected: FAIL — `PresenceEngine` does not exist.

- [ ] **Step 7: Implement PresenceEngine**

```swift
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
```

- [ ] **Step 8: Run to verify pass**

Run: `swift test --filter PresenceEngineTests`
Expected: PASS (4 tests).

- [ ] **Step 9: Commit**

```bash
git add Sources/ScreenTime/Core/PresenceEngine.swift Sources/ScreenTime/Core/DayKey.swift Tests/ScreenTimeTests/PresenceEngineTests.swift Tests/ScreenTimeTests/DayKeyTests.swift
git commit -m "feat: add pure presence engine and day-key logic"
```

---

### Task 4: SQLite storage

**Files:**
- Create: `Sources/ScreenTime/Data/ScreenTimeStore.swift`
- Test: `Tests/ScreenTimeTests/ScreenTimeStoreTests.swift`

**Interfaces:**
- Produces: `ScreenTimeStore(path: String) throws`, `.save(day: String, seconds: Int)`, `.secondsForDay(_ day: String) -> Int`, `.allDays() -> [String: Int]`, `static .defaultPath() -> String`. Used by Task 5 (`PresenceTracker`) and Task 10 (`YearHeatmapView`).

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ScreenTimeStoreTests`
Expected: FAIL — `ScreenTimeStore` does not exist.

- [ ] **Step 3: Implement**

```swift
import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum ScreenTimeStoreError: Error {
    case openFailed(String)
    case executeFailed(String)
}

final class ScreenTimeStore {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw ScreenTimeStoreError.openFailed(message)
        }
        try execute("""
            CREATE TABLE IF NOT EXISTS screen_time (
                day TEXT PRIMARY KEY,
                seconds INTEGER NOT NULL
            );
            """)
    }

    deinit {
        sqlite3_close(db)
    }

    static func defaultPath() -> String {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenTime", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        return supportDir.appendingPathComponent("screentime.sqlite3").path
    }

    func save(day: String, seconds: Int) {
        let sql = "INSERT INTO screen_time (day, seconds) VALUES (?, ?) ON CONFLICT(day) DO UPDATE SET seconds = excluded.seconds;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, day, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 2, Int64(seconds))
        sqlite3_step(statement)
    }

    func secondsForDay(_ day: String) -> Int {
        let sql = "SELECT seconds FROM screen_time WHERE day = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, day, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    func allDays() -> [String: Int] {
        let sql = "SELECT day, seconds FROM screen_time;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(statement) }
        var result: [String: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let day = String(cString: sqlite3_column_text(statement, 0))
            let seconds = Int(sqlite3_column_int64(statement, 1))
            result[day] = seconds
        }
        return result
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorPointer) != SQLITE_OK {
            let message = errorPointer.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorPointer)
            throw ScreenTimeStoreError.executeFailed(message)
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter ScreenTimeStoreTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/ScreenTime/Data/ScreenTimeStore.swift Tests/ScreenTimeTests/ScreenTimeStoreTests.swift
git commit -m "feat: add SQLite-backed screen time store"
```

---

### Task 5: Presence tracker (OS-facing shell)

**Files:**
- Create: `Sources/ScreenTime/Core/PresenceTracker.swift`
- Test: `Tests/ScreenTimeTests/PresenceTrackerTests.swift`

**Interfaces:**
- Consumes: `PresenceEngine`, `PresenceEngine.State`, `DayKey.forDate`, `ScreenTimeStore` (Task 3, 4).
- Produces: `PresenceTracker: ObservableObject`, `@Published private(set) var state: PresenceEngine.State`, `let store: ScreenTimeStore`, `.start()`, `.tick()`, `.handleSystemSleep()`, `.handleSystemWake()`. Used by Task 8, 9, 10.

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter PresenceTrackerTests`
Expected: FAIL — `PresenceTracker` does not exist.

- [ ] **Step 3: Implement**

```swift
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
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
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
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter PresenceTrackerTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/ScreenTime/Core/PresenceTracker.swift Tests/ScreenTimeTests/PresenceTrackerTests.swift
git commit -m "feat: add OS-facing presence tracker"
```

---

### Task 6: Heatmap layout (pure logic)

**Files:**
- Create: `Sources/ScreenTime/Core/HeatmapLayout.swift`
- Test: `Tests/ScreenTimeTests/HeatmapLayoutTests.swift`

**Interfaces:**
- Consumes: `DayKey.forDate` (Task 3).
- Produces: `HeatmapLayout.weeks(forYear: Int) -> [[Date?]]`, `.color(forSeconds: Int) -> Color`. Used by Task 10 (`YearHeatmapView`).

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter HeatmapLayoutTests`
Expected: FAIL — `HeatmapLayout` does not exist.

- [ ] **Step 3: Implement**

```swift
import Foundation
import SwiftUI

enum HeatmapLayout {
    static func weeks(forYear year: Int) -> [[Date?]] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let dec31 = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: jan1) // 1 = Sunday
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        var current = jan1
        while current <= dec31 {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        while days.count % 7 != 0 { days.append(nil) }
        var weeks: [[Date?]] = []
        var index = 0
        while index < days.count {
            weeks.append(Array(days[index..<index + 7]))
            index += 7
        }
        return weeks
    }

    static func color(forSeconds seconds: Int) -> Color {
        let hours = Double(seconds) / 3600.0
        switch hours {
        case ..<0.01: return Color.gray.opacity(0.15)
        case ..<2: return Color.green.opacity(0.3)
        case ..<4: return Color.green.opacity(0.55)
        case ..<6: return Color.green.opacity(0.75)
        default: return Color.green.opacity(1.0)
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter HeatmapLayoutTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/ScreenTime/Core/HeatmapLayout.swift Tests/ScreenTimeTests/HeatmapLayoutTests.swift
git commit -m "feat: add year heatmap layout logic"
```

---

### Task 7: Login item manager

**Files:**
- Create: `Sources/ScreenTime/Core/LoginItemManager.swift`

**Interfaces:**
- Produces: `LoginItemManager.isEnabled: Bool`, `.setEnabled(_ enabled: Bool) throws`. Used by Task 8.

No automated test here — `SMAppService` requires a real, code-signed `.app` bundle to behave correctly, which doesn't exist until Task 11. This task just writes the thin wrapper; end-to-end behavior is manually verified in Task 11.

- [ ] **Step 1: Implement**

```swift
import ServiceManagement

enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: builds with no errors (this type isn't exercised at runtime until Task 8/11).

- [ ] **Step 3: Commit**

```bash
git add Sources/ScreenTime/Core/LoginItemManager.swift
git commit -m "feat: add login item manager wrapper"
```

---

### Task 8: Menu bar UI

**Files:**
- Modify: `Sources/ScreenTime/ScreenTimeApp.swift` (full rewrite, replaces Task 1's smoke test)
- Create: `Sources/ScreenTime/UI/MenuBarContentView.swift`

**Interfaces:**
- Consumes: `PresenceTracker`, `ScreenTimeStore.defaultPath()` (Task 4, 5), `TimeFormatting.format` (Task 2), `LoginItemManager` (Task 7).
- Produces: running app with live menu bar icon + dropdown. Extended by Task 9 (widget toggle) and Task 10 (year view button + Window scene).

- [ ] **Step 1: Write the dropdown content view**

```swift
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var tracker: PresenceTracker
    @State private var loginItemEnabled = LoginItemManager.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.default, value: tracker.state.todaySeconds)

            Divider()

            Toggle("Open at Login", isOn: $loginItemEnabled)
                .onChange(of: loginItemEnabled) { _, newValue in
                    try? LoginItemManager.setEnabled(newValue)
                }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 220)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}
```

- [ ] **Step 2: Rewrite the app entry point**

```swift
import SwiftUI

@main
struct ScreenTimeApp: App {
    @StateObject private var tracker: PresenceTracker

    init() {
        let store = try! ScreenTimeStore(path: ScreenTimeStore.defaultPath())
        let tracker = PresenceTracker(store: store)
        tracker.start()
        _tracker = StateObject(wrappedValue: tracker)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(tracker: tracker)
        } label: {
            Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Manual verification**

Run: `swift run`
Expected: menu bar shows live-updating "0h 0m" (or higher if today already has data from earlier test runs against the default store path). Move the mouse — number should climb by 15s roughly every 15s. Click the icon: dropdown shows the big number, an "Open at Login" toggle, and Quit. Leave the Mac untouched for 2+ minutes: number should stop climbing. Touch the trackpad again: it should resume.

- [ ] **Step 4: Commit**

```bash
git add Sources/ScreenTime/ScreenTimeApp.swift Sources/ScreenTime/UI/MenuBarContentView.swift
git commit -m "feat: wire up live menu bar UI"
```

---

### Task 9: Floating widget

**Files:**
- Create: `Sources/ScreenTime/UI/FloatingWidgetController.swift`
- Create: `Sources/ScreenTime/UI/WidgetView.swift`
- Modify: `Sources/ScreenTime/UI/MenuBarContentView.swift` (add widget toggle)
- Modify: `Sources/ScreenTime/ScreenTimeApp.swift` (own the controller)

**Interfaces:**
- Consumes: `PresenceTracker` (Task 5), `TimeFormatting.format` (Task 2).
- Produces: `FloatingWidgetController: ObservableObject` with `@Published var isVisible: Bool`, `WidgetView`. Wired into the app in this task; nothing else depends on it later.

- [ ] **Step 1: Write the widget content view**

```swift
import SwiftUI

struct WidgetView: View {
    @ObservedObject var tracker: PresenceTracker

    var body: some View {
        Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .contentTransition(.numericText())
            .animation(.default, value: tracker.state.todaySeconds)
            .padding(16)
            .frame(width: 160, height: 60)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: Write the panel controller**

```swift
import AppKit
import SwiftUI

final class FloatingWidgetController: ObservableObject {
    @Published var isVisible: Bool = false {
        didSet { isVisible ? show() : hide() }
    }

    private var panel: NSPanel?
    private let tracker: PresenceTracker

    init(tracker: PresenceTracker) {
        self.tracker = tracker
    }

    private func show() {
        guard panel == nil else { return }
        let hosting = NSHostingView(rootView: WidgetView(tracker: tracker))
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 60),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.level = .floating
        newPanel.contentView = hosting
        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel
    }

    private func hide() {
        panel?.close()
        panel = nil
    }
}
```

- [ ] **Step 3: Add the toggle to the dropdown**

In `Sources/ScreenTime/UI/MenuBarContentView.swift`, add a parameter and a toggle row (full updated file):

```swift
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var tracker: PresenceTracker
    @ObservedObject var widgetController: FloatingWidgetController
    @State private var loginItemEnabled = LoginItemManager.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.default, value: tracker.state.todaySeconds)

            Toggle("Floating Widget", isOn: $widgetController.isVisible)

            Divider()

            Toggle("Open at Login", isOn: $loginItemEnabled)
                .onChange(of: loginItemEnabled) { _, newValue in
                    try? LoginItemManager.setEnabled(newValue)
                }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 220)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}
```

- [ ] **Step 4: Wire the controller into the app**

Full updated `Sources/ScreenTime/ScreenTimeApp.swift`:

```swift
import SwiftUI

@main
struct ScreenTimeApp: App {
    @StateObject private var tracker: PresenceTracker
    @StateObject private var widgetController: FloatingWidgetController

    init() {
        let store = try! ScreenTimeStore(path: ScreenTimeStore.defaultPath())
        let tracker = PresenceTracker(store: store)
        tracker.start()
        _tracker = StateObject(wrappedValue: tracker)
        _widgetController = StateObject(wrappedValue: FloatingWidgetController(tracker: tracker))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(tracker: tracker, widgetController: widgetController)
        } label: {
            Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Manual verification**

Run: `swift run`
Expected: toggling "Floating Widget" on shows a small glass panel with the live number; drag it anywhere on screen by clicking its background; it stays on top of other windows. Toggle off closes it. Toggle on again re-opens at screen center.

- [ ] **Step 6: Commit**

```bash
git add Sources/ScreenTime/UI/FloatingWidgetController.swift Sources/ScreenTime/UI/WidgetView.swift Sources/ScreenTime/UI/MenuBarContentView.swift Sources/ScreenTime/ScreenTimeApp.swift
git commit -m "feat: add floating desktop widget"
```

---

### Task 10: Year heatmap view

**Files:**
- Create: `Sources/ScreenTime/UI/YearHeatmapView.swift`
- Modify: `Sources/ScreenTime/UI/MenuBarContentView.swift` (add "View Year" button)
- Modify: `Sources/ScreenTime/ScreenTimeApp.swift` (add Window scene)

**Interfaces:**
- Consumes: `HeatmapLayout` (Task 6), `ScreenTimeStore.allDays()` (Task 4), `TimeFormatting.format` (Task 2), `DayKey.forDate` (Task 3).
- Produces: a "year-view" `Window` scene opened via `openWindow(id:)` from the dropdown. Nothing later depends on this.

- [ ] **Step 1: Write the heatmap view**

```swift
import SwiftUI

private struct IdentifiableDay: Identifiable {
    let value: String
    var id: String { value }
}

struct YearHeatmapView: View {
    let store: ScreenTimeStore
    @State private var data: [String: Int] = [:]
    @State private var selectedDay: IdentifiableDay?

    private var year: Int { Calendar.current.component(.year, from: Date()) }
    private var weeks: [[Date?]] { HeatmapLayout.weeks(forYear: year) }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 3) {
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            daySquare(for: weeks[weekIndex][dayIndex])
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 900, minHeight: 200)
        .glassEffect(.regular, in: Rectangle())
        .onAppear { data = store.allDays() }
        .popover(item: $selectedDay) { day in
            VStack(alignment: .leading, spacing: 8) {
                Text(day.value).font(.headline)
                Text(TimeFormatting.format(seconds: data[day.value] ?? 0))
                    .font(.title2)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func daySquare(for date: Date?) -> some View {
        if let date {
            let key = DayKey.forDate(date)
            Rectangle()
                .fill(HeatmapLayout.color(forSeconds: data[key] ?? 0))
                .frame(width: 12, height: 12)
                .cornerRadius(3)
                .onTapGesture { selectedDay = IdentifiableDay(value: key) }
        } else {
            Rectangle().fill(.clear).frame(width: 12, height: 12)
        }
    }
}
```

- [ ] **Step 2: Add the "View Year" button**

Full updated `Sources/ScreenTime/UI/MenuBarContentView.swift`:

```swift
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var tracker: PresenceTracker
    @ObservedObject var widgetController: FloatingWidgetController
    @State private var loginItemEnabled = LoginItemManager.isEnabled
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.default, value: tracker.state.todaySeconds)

            Button("View Year") {
                openWindow(id: "year-view")
            }

            Toggle("Floating Widget", isOn: $widgetController.isVisible)

            Divider()

            Toggle("Open at Login", isOn: $loginItemEnabled)
                .onChange(of: loginItemEnabled) { _, newValue in
                    try? LoginItemManager.setEnabled(newValue)
                }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 220)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}
```

- [ ] **Step 3: Add the Window scene**

Full updated `Sources/ScreenTime/ScreenTimeApp.swift`:

```swift
import SwiftUI

@main
struct ScreenTimeApp: App {
    @StateObject private var tracker: PresenceTracker
    @StateObject private var widgetController: FloatingWidgetController

    init() {
        let store = try! ScreenTimeStore(path: ScreenTimeStore.defaultPath())
        let tracker = PresenceTracker(store: store)
        tracker.start()
        _tracker = StateObject(wrappedValue: tracker)
        _widgetController = StateObject(wrappedValue: FloatingWidgetController(tracker: tracker))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(tracker: tracker, widgetController: widgetController)
        } label: {
            Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
        }
        .menuBarExtraStyle(.window)

        Window("Year", id: "year-view") {
            YearHeatmapView(store: tracker.store)
        }
    }
}
```

- [ ] **Step 4: Seed fake data and verify visually**

Run: `swift run` once, then quit. Use the SQLite CLI to seed a populated year so the heatmap isn't empty:

Run:
```bash
sqlite3 "$HOME/Library/Application Support/ScreenTime/screentime.sqlite3" \
  "INSERT OR REPLACE INTO screen_time VALUES ('2026-01-05', 3600), ('2026-02-14', 18000), ('2026-03-20', 7200);"
```

Run: `swift run`, click the menu bar icon, click "View Year".
Expected: a new window opens showing the full-year grid; Jan 5, Feb 14, Mar 20 show visibly darker/greener squares than empty days; clicking a colored square pops over the exact hours for that day; clicking an empty square shows "0h 0m".

- [ ] **Step 5: Commit**

```bash
git add Sources/ScreenTime/UI/YearHeatmapView.swift Sources/ScreenTime/UI/MenuBarContentView.swift Sources/ScreenTime/ScreenTimeApp.swift
git commit -m "feat: add year heatmap history view"
```

---

### Task 11: App bundle packaging

**Files:**
- Create: `Resources/Info.plist`
- Create: `Scripts/build_app.sh`

**Interfaces:**
- Produces: a real, launchable `.app` bundle with no Dock icon, needed for `LoginItemManager` (Task 7) to actually work.

- [ ] **Step 1: Write the Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ScreenTime</string>
    <key>CFBundleIdentifier</key>
    <string>com.ethanpeleg.screentime</string>
    <key>CFBundleExecutable</key>
    <string>ScreenTime</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

- [ ] **Step 2: Write the build script**

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="ScreenTime"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
```

- [ ] **Step 3: Make it executable and run it**

Run: `chmod +x Scripts/build_app.sh && ./Scripts/build_app.sh`
Expected: prints `Built .build/release/ScreenTime.app` with no errors.

- [ ] **Step 4: Manual verification — no Dock icon**

Run: `open .build/release/ScreenTime.app`
Expected: menu bar icon appears; no icon appears in the Dock; no icon appears in Cmd+Tab app switcher.

- [ ] **Step 5: Manual verification — login item**

Move `ScreenTime.app` to `/Applications`, relaunch it from there, toggle "Open at Login" on in the dropdown.
Expected: entry for ScreenTime appears in System Settings → General → Login Items & Extensions. Toggle off — entry disappears.

- [ ] **Step 6: Commit**

```bash
git add Resources/Info.plist Scripts/build_app.sh
git commit -m "chore: add app bundle packaging script"
```

---

### Task 12: Final integration QA

No new files — this is a manual end-to-end pass against the spec's testing checklist.

- [ ] **Step 1: Sleep/wake cycle**

Close the laptop lid (or Apple menu → Sleep) while ScreenTime is running with a nonzero today count. Wake it up.
Expected: the counted seconds during sleep are not added; counting resumes normally after wake.

- [ ] **Step 2: Lock/unlock cycle**

Lock the screen (Cmd+Ctrl+Q) for at least 30 seconds, then unlock.
Expected: no time added while locked; counting resumes on unlock.

- [ ] **Step 3: Force-quit persistence**

Let the app run and accumulate at least 1 minute of active time, then `killall ScreenTime` (or force-quit via Activity Monitor).
Expected: relaunching shows a today count no more than ~30 seconds behind where it was killed (per the 30s persist cadence).

- [ ] **Step 4: Idle timeout**

Leave the mouse/keyboard untouched for 2+ minutes while the app is frontmost and unlocked.
Expected: the counter stops climbing after ~2 minutes idle, and resumes immediately on the next keystroke/click.

- [ ] **Step 5: Midnight rollover**

Set the system clock forward past midnight (System Settings → Date & Time, temporarily disable "Set automatically") while the app is running.
Expected: today's counter resets to 0 for the new day; the previous day's total is visible and correct in the year heatmap. Re-enable automatic date/time afterward.

- [ ] **Step 6: Widget + heatmap full pass**

Toggle the floating widget on, drag it to a corner, confirm it tracks the same live number as the menu bar. Open the year view, confirm today's square updates color after enough accumulated time, confirm popovers show correct per-day hours.
