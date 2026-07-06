# Live seconds in menu bar popover

## Problem
Popover shows "0h 35m" — no seconds. `PresenceEngine` ticks every 15s (by design, for battery/CPU efficiency), so `todaySeconds` only advances in 15s jumps. Showing live per-second updates needs a faster clock somewhere, but must not regress the existing efficiency of the tracker.

## Goal
Popover displays seconds, updating every second while visible. No change to background tick rate, persistence cadence, or battery cost when popover is closed.

## Approach
Interpolate, don't accelerate. `PresenceEngine`'s 15s tick interval and 30s persistence cadence stay untouched. A separate 1Hz timer lives entirely in the popover view, running only while the popover is open, and computes a display value by adding elapsed wall-clock time to the last known `todaySeconds`. Each real engine tick resyncs the baseline, self-correcting any drift (bounded by the 15s tick interval — worst case the display over-counts by up to 15s during an idle transition, then snaps back at the next tick).

Rejected: dropping engine tick interval to 1s. Same effect but pays the 1s cost all day, everywhere, not just when the popover is open. 15x more idle-check syscalls and timer wakeups for no benefit outside the popover.

## Changes

**`PresenceTracker`**
- Track `lastTickAt: Date`, set in `init` and on every `tick()`.
- Add `func liveSeconds() -> Int`: returns `state.todaySeconds` unchanged if `systemActive` is false (sleep/screen off); otherwise adds `max(0, clock().timeIntervalSince(lastTickAt))` to it.

**`TimeFormatting`**
- Add `format(seconds:includeSeconds:)` (or a second function) producing `"0h 35m 12s"`. Existing `format(seconds:)` stays as-is for the menu bar icon (icon does not tick seconds — confirmed out of scope).

**`MenuBarContentView`**
- Add `@State private var displaySeconds: Int` and a `Timer?` owned by the view.
- `onAppear`: set `displaySeconds = tracker.liveSeconds()`, start a 1s repeating timer updating `displaySeconds` from `tracker.liveSeconds()`.
- `onDisappear`: invalidate and clear the timer.
- `onChange(of: tracker.state.todaySeconds)`: resync `displaySeconds` immediately (covers day rollover and the moment a real engine tick lands while popover is open).
- Render with the seconds-inclusive formatter instead of the current one.

**`ScreenTimeApp.swift`**
- No change. Menu bar icon/label keeps minute-granularity formatting.

## Out of scope
- Menu bar icon ticking seconds (explicitly declined).
- Any change to `PresenceEngine` tick/persist intervals.
