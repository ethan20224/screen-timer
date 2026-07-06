# ScreenTime — Design Spec

## Problem

Existing screen time trackers count "laptop powered on" time, not "actually looking at / using the laptop" time. User leaves computer on all day, so numbers are inflated and useless. Need a tracker that only counts real active-use time, presented Apple-style, on this Mac (macOS Tahoe / 26+).

## Scope (v1)

- Local-only, single Mac. No cross-device sync (deferred — revisit later if needed).
- Total active screen time per day only. No per-app breakdown.
- No camera use. Presence detected purely from input activity + system sleep/lock state.

## Presence Detection

- Poll system idle time every ~15s via `CGEventSource.secondsSinceLastEventType`.
- If idle time < 2 minutes AND screen is not locked AND display is not asleep → count as active, accumulate seconds.
- If idle ≥ 2 minutes, OR screen locked, OR display/system asleep → stop counting immediately. Resumes instantly on next input.
- Screen lock/sleep detected via `NSWorkspace` notifications: `screensDidSleepNotification`, `screensDidWakeNotification`, `sessionDidResignActiveNotification`, `sessionDidBecomeActiveNotification`.
- Known limitation (accepted for v1): passive activity with no input (reading, watching video) for 2+ min gets marked "away" and undercounts. Not solved in v1 — revisit only if it proves annoying in practice.

## Data & Storage

- Local SQLite database on-device. One row per calendar day: `date`, `active_seconds`.
- Day boundary = local midnight. At rollover, current day's row finalizes and a new row starts — no manual reset.
- Persist accumulated seconds to disk every ~30s so a crash/force-quit loses at most ~30s of data.
- No network calls, no cloud storage in v1.

## App Behavior

- Launch at login via `SMAppService`, runs silently in background (no dock icon — `LSUIElement`).
- Menu bar icon (`NSStatusItem`) shows live-updating today's total, e.g. "3h 42m".
- Click icon → dropdown panel: today's number (large, ticking live) + button to open full year view.
- Optional floating desktop widget: separate always-on-top panel window, draggable anywhere, shows same live number. Toggled on/off from the menu bar dropdown. Independent of dropdown — can stay open while dropdown is closed.

## Year View

- Full-year calendar heatmap (GitHub-contributions style): one square per day, darker = more active hours that day.
- Click a day square → shows exact active hours/minutes for that date.
- Opens as its own window from the menu bar dropdown button.

## Visual Style

- Native SwiftUI, macOS 26 (Tahoe)+ only — no legacy fallback needed.
- Liquid Glass material for dropdown panel, widget, and year-view window backgrounds.
- SF Pro typography, rounded corners, smooth number-ticking animation on live counters, automatic light/dark mode matching system appearance.

## Out of Scope (v1, explicitly deferred)

- Cross-device sync (iPhone/other Macs) — flagged by user as a future want, not designed here.
- Per-app time breakdown.
- Camera-based or audio-based presence fallback for passive-activity edge case.
- Historical data export/import.

## Testing

- Unit test idle-threshold logic (active/inactive transitions) with mocked idle-time values.
- Unit test day-rollover logic across midnight boundary.
- Manual QA: sleep/wake cycle, lock/unlock cycle, force-quit/relaunch data persistence, launch-at-login behavior, widget drag + toggle, heatmap rendering across a populated year of fake data.
