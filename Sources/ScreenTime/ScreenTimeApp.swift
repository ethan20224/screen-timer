import SwiftUI

@main
struct ScreenTimeApp: App {
    @StateObject private var tracker: PresenceTracker
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    @AppStorage("typographyStyle") private var typographyStyleRaw = TypographyStyle.roundedMedium.rawValue

    private var typographyStyle: TypographyStyle {
        TypographyStyle(rawValue: typographyStyleRaw) ?? .roundedMedium
    }

    init() {
        let store = try! ScreenTimeStore(path: ScreenTimeStore.defaultPath())
        let tracker = PresenceTracker(store: store)
        tracker.start()
        _tracker = StateObject(wrappedValue: tracker)

        try? LoginItemManager.setEnabled(true)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(tracker: tracker)
        } label: {
            if showMenuBarIcon {
                Label {
                    Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
                        .font(typographyStyle.font(size: 13, weight: .medium).monospacedDigit())
                        .tracking(typographyStyle.tracking)
                } icon: {
                    Image(systemName: "timer")
                }
                .labelStyle(.titleAndIcon)
            } else {
                Text(TimeFormatting.format(seconds: tracker.state.todaySeconds))
                    .font(typographyStyle.font(size: 13, weight: .medium).monospacedDigit())
                    .tracking(typographyStyle.tracking)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
