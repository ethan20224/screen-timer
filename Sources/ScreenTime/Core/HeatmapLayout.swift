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
