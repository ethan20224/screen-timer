import SwiftUI

enum DesignTokens {
    enum Spacing {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum Radius {
        static let panel: CGFloat = 20
        static let cell: CGFloat = 3
    }

    enum Motion {
        static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
        static let hover = Animation.easeOut(duration: 0.12)
    }

    enum PanelWidth {
        static let compact: CGFloat = 220
        static let expanded: CGFloat = 380
    }

    static let defaultAccentHex = "298C73"
    static let accent = Color(hex: defaultAccentHex)

    static func heatmapColor(forSeconds seconds: Int, accent: Color = accent) -> Color {
        let hours = Double(seconds) / 3600.0
        let intensity = min(max(hours / 6.0, 0), 1)
        guard intensity > 0 else {
            return Color.gray.opacity(0.12)
        }
        return accent.opacity(0.18 + intensity * 0.82)
    }
}
