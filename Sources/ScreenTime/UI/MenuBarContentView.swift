import AppKit
import SwiftUI

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DesignTokens.Motion.press, value: configuration.isPressed)
    }
}

struct MenuBarContentView: View {
    @ObservedObject var tracker: PresenceTracker
    @State private var showHistory = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    @AppStorage("typographyStyle") private var typographyStyleRaw = TypographyStyle.roundedMedium.rawValue
    @AppStorage("accentColorHex") private var accentColorHex = DesignTokens.defaultAccentHex

    private var typographyStyle: TypographyStyle {
        TypographyStyle(rawValue: typographyStyleRaw) ?? .roundedMedium
    }

    private var accentColor: Color {
        Color(hex: accentColorHex)
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { Color(hex: accentColorHex) },
            set: { accentColorHex = $0.hexString }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accentColor)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + d.height * 0.1 }

                FluidNumberText(
                    text: TimeFormatting.format(seconds: tracker.state.todaySeconds),
                    font: typographyStyle.font(size: 28, weight: .semibold).monospacedDigit(),
                    tracking: typographyStyle.tracking
                )
            }

            Divider()

            Button {
                showHistory.toggle()
            } label: {
                HStack {
                    Text("View History")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showHistory ? 90 : 0))
                        .animation(DesignTokens.Motion.hover, value: showHistory)
                }
            }
            .buttonStyle(PressableButtonStyle())

            if showHistory {
                HeatmapView(store: tracker.store, accent: accentColor)
                    .frame(width: DesignTokens.PanelWidth.expanded - DesignTokens.Spacing.lg * 2)
            }

            Divider()

            Toggle("Show Icon in Menu Bar", isOn: $showMenuBarIcon)

            Picker("Typography", selection: $typographyStyleRaw) {
                ForEach(TypographyStyle.allCases) { style in
                    Text(style.label).tag(style.rawValue)
                }
            }
            .pickerStyle(.menu)

            ColorPicker("Accent Color", selection: accentBinding, supportsOpacity: false)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: showHistory ? DesignTokens.PanelWidth.expanded : DesignTokens.PanelWidth.compact)
        .animation(DesignTokens.Motion.hover, value: showHistory)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.panel))
        .onAppear {
            let performer = NSHapticFeedbackManager.defaultPerformer
            performer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                performer.perform(.levelChange, performanceTime: .now)
            }
        }
    }
}
