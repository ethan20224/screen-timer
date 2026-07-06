import SwiftUI

struct HeatmapView: View {
    let store: ScreenTimeStore
    var accent: Color = DesignTokens.accent
    @State private var hoveredDate: Date?

    private var year: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var weeks: [[Date?]] {
        HeatmapLayout.weeks(forYear: year)
    }

    private var days: [String: Int] {
        store.allDays()
    }

    private var hasHistory: Bool {
        days.count > 1
    }

    var body: some View {
        if hasHistory {
            grid
        } else {
            Text("Tracking started today. Come back tomorrow to see your history.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 3) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        cell(for: date)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for date: Date?) -> some View {
        if let date {
            let seconds = days[DayKey.forDate(date)] ?? 0
            RoundedRectangle(cornerRadius: DesignTokens.Radius.cell)
                .fill(DesignTokens.heatmapColor(forSeconds: seconds, accent: accent))
                .frame(width: 10, height: 10)
                .scaleEffect(hoveredDate == date ? 1.3 : 1)
                .animation(DesignTokens.Motion.hover, value: hoveredDate)
                .onHover { isHovering in
                    hoveredDate = isHovering ? date : nil
                }
        } else {
            Color.clear.frame(width: 10, height: 10)
        }
    }
}
