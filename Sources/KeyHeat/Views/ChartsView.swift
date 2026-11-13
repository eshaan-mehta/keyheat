import Charts
import SwiftUI

// MARK: - Ranked keys

/// Ranked bars in a single accent. Shows `visibleRows` at a time and scrolls
/// for the rest, so the list can hold every key without dominating the page.
/// Bar lengths follow the same scale as the heatmap, so that the least
/// pressed keys still get a readable bar next to the most pressed ones.
struct RankedKeysChart: View {
    let keys: [KeyCount]
    let total: Int
    let scale: HeatScale
    var visibleRows = 15

    var body: some View {
        if keys.isEmpty {
            EmptyNote(text: "No presses in this range yet.")
        } else {
            let maxCount = keys.map(\.count).max() ?? 1
            ScrollView(.vertical) {
                HBarList(
                    rows: keys.map { k in
                        HBarRow(id: k.info.name,
                                label: k.info.name,
                                value: k.count,
                                fraction: scale.normalize(k.count, max: maxCount),
                                color: Palette.accentBlue,
                                valueLabel: k.count.formatted(),
                                hoverLabel: "\(k.count.formatted()) · \(Fmt.percent(total > 0 ? Double(k.count) / Double(total) : 0))")
                    },
                    labelWidth: 112   // fits "Forward Delete" and "Right Command"
                )
            }
            .frame(height: HBarList.height(rows: min(keys.count, visibleRows)))
        }
    }
}

// MARK: - Timeline

struct TimelineChart: View {
    let periods: [PeriodCount]
    let unit: Calendar.Component
    /// When set, only this period is drawn in the accent; the rest are context.
    var highlight: Date? = nil
    @State private var selected: Date?

    private func color(_ p: PeriodCount) -> Color {
        guard let highlight else { return Palette.accentBlue }
        return p.start == highlight ? Palette.accentBlue : Palette.context
    }

    private func isSelected(_ p: PeriodCount) -> Bool {
        guard let selected else { return false }
        return Calendar.current.dateInterval(of: unit, for: selected)?.start == p.start
    }

    private func label(_ d: Date) -> String {
        switch unit {
        case .weekOfYear: return "Week of " + d.formatted(.dateTime.month(.abbreviated).day())
        default: return d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    var body: some View {
        if periods.isEmpty {
            EmptyNote(text: "Nothing recorded yet.")
        } else {
            let peak = periods.max { $0.count < $1.count }
            let labeled = highlight.flatMap { h in periods.first { $0.start == h } } ?? peak
            Chart(periods) { p in
                BarMark(x: .value("Time", p.start, unit: unit), y: .value("Presses", p.count))
                    .foregroundStyle(color(p))
                    .opacity(selected == nil || isSelected(p) ? 1 : 0.35)
                    .cornerRadius(2)
                    .annotation(position: .top, alignment: .center, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        if isSelected(p) {
                            ChartTip(title: label(p.start), value: "\(p.count.formatted()) presses")
                        } else if selected == nil, let labeled, labeled.count > 0, labeled.start == p.start {
                            Text(Fmt.compact(p.count)).font(.system(size: 11)).foregroundStyle(Palette.inkSecondary)
                        }
                    }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) {
                    AxisValueLabel(format: Date.FormatStyle.dateTime.month(.abbreviated).day())
                        .foregroundStyle(Palette.muted)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel().foregroundStyle(Palette.muted)
                }
            }
            .chartXSelection(value: $selected)
            .chartLegend(.hidden)
            .frame(height: 200)
        }
    }
}

// MARK: - Hand balance

struct HandBalanceView: View {
    let left: Int
    let right: Int

    var body: some View {
        let total = left + right
        let leftFrac = total > 0 ? Double(left) / Double(total) : 0.5
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    Rectangle().fill(Palette.accentBlue).frame(width: max(0, (geo.size.width - 3) * leftFrac))
                    Rectangle().fill(Palette.accentWarm)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)

            HStack(alignment: .top) {
                HandLabel(color: Palette.accentBlue, name: "Left hand", count: left, frac: leftFrac)
                Spacer()
                HandLabel(color: Palette.accentWarm, name: "Right hand", count: right, frac: 1 - leftFrac, trailing: true)
            }
            Text("By physical key position. The space bar is a thumb key and is left out.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
    }
}

private struct HandLabel: View {
    let color: Color
    let name: String
    let count: Int
    let frac: Double
    var trailing = false

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            HStack(spacing: 6) {
                if !trailing { Circle().fill(color).frame(width: 7, height: 7) }
                Text(name).font(.system(size: 12)).foregroundStyle(Palette.inkSecondary)
                if trailing { Circle().fill(color).frame(width: 7, height: 7) }
            }
            Text(Fmt.percent(frac)).font(.system(size: 20, weight: .medium)).foregroundStyle(Palette.ink)
            Text("\(count.formatted()) presses").font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
    }
}
