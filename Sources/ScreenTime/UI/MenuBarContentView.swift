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
                    do {
                        try LoginItemManager.setEnabled(newValue)
                    } catch {
                        loginItemEnabled = LoginItemManager.isEnabled
                    }
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
