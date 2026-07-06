# Screen Timer

macOS menu bar app tracking daily screen time with live heatmap visualization.

## Features

- **Live Menu Bar Display** — See your screen time in real-time without opening a window
- **Daily Heatmap** — Visual breakdown of activity patterns across the day
- **Automatic Tracking** — Runs in background, no manual logging needed
- **Idle Detection** — Distinguishes active use from passive viewing (120s default threshold)
- **Sleep Aware** — Pauses tracking when Mac sleeps or display turns off
- **Persistent Storage** — SQLite database stores historical data

## Architecture

- **PresenceTracker** — Core tracking engine (15s polling interval)
- **PresenceEngine** — State machine managing active/idle transitions
- **HeatmapView** — Real-time UI visualization
- **DesignTokens** — Unified colors, typography, and spacing system
- **MenuBar Integration** — Native macOS menu bar integration

## Build & Run

### Requirements
- macOS 26+
- Swift 6.2+
- Xcode 16+

### Build
```bash
cd screen-timer
swift build -c release
```

### Run
```bash
.build/release/ScreenTime
```

Or build and run script:
```bash
bash scripts/build-app.sh
```

## Setup for Users

1. **Build from source** (above) or download release binary
2. **Run the app** — it installs as menu bar item automatically
3. **Grant accessibility permissions** — macOS will prompt on first launch
   - System Settings → Privacy & Security → Accessibility
   - Add ScreenTime to the list
4. **Done** — tracking starts immediately. Click menu bar icon to see heatmap

## Accuracy Notes

**±15s granularity** — Polling every 15 seconds means short bursts (<15s) may be lost, tail of sessions may be rounded.

**Passive viewing undercounting** — If you read without keyboard/mouse input for >120s, time stops counting (intentional to avoid counting idle time). Adjust `idleThresholdSeconds` in `PresenceTracker.init()` to change this.

**Display-off edge case** — Monitors powered down but Mac awake will still count time (known limitation).

## Data Storage

All screen time data stored locally in:
```
~/Library/Application Support/ScreenTime/screentime.db
```

No cloud sync, no telemetry.

## Development

### Key Files
- `Sources/ScreenTime/Core/PresenceTracker.swift` — Main tracking loop
- `Sources/ScreenTime/Core/PresenceEngine.swift` — State machine
- `Sources/ScreenTime/UI/HeatmapView.swift` — Heatmap visualization
- `Sources/ScreenTime/UI/MenuBarContentView.swift` — Menu bar UI

### Tests
```bash
swift test
```

## License

MIT
