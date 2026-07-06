import SwiftUI

enum TypographyStyle: String, CaseIterable, Identifiable {
    case roundedMedium
    case roundedBold
    case systemDefault
    case systemBold
    case monospacedStyle
    case serifStyle
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .roundedMedium: return "Rounded Medium"
        case .roundedBold: return "Rounded Bold"
        case .systemDefault: return "System Default"
        case .systemBold: return "System Bold"
        case .monospacedStyle: return "Monospaced"
        case .serifStyle: return "Serif"
        case .compact: return "Compact"
        }
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .roundedMedium: return .system(size: size, weight: weight, design: .rounded)
        case .roundedBold: return .system(size: size, weight: .bold, design: .rounded)
        case .systemDefault: return .system(size: size, weight: weight, design: .default)
        case .systemBold: return .system(size: size, weight: .bold, design: .default)
        case .monospacedStyle: return .system(size: size, weight: weight, design: .monospaced)
        case .serifStyle: return .system(size: size, weight: weight, design: .serif)
        case .compact: return .system(size: size, weight: weight, design: .default)
        }
    }

    var tracking: CGFloat {
        self == .compact ? -1.2 : 0
    }
}
