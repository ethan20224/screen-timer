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
