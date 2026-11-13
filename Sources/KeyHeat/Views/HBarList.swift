import SwiftUI

struct HBarRow: Identifiable {
    let id: String
    let label: String
    let value: Int
    /// Bar length as a share of the track, 0...1. Computed by the caller so
    /// the list does not need to know about scales.
    let fraction: Double
    let color: Color
    /// Text shown at the end of the bar.
    let valueLabel: String
    /// Text shown instead of `valueLabel` while the row is hovered.
    var hoverLabel: String? = nil
}

/// Horizontal bar list with a fixed label column, thin rounded bars, a value
/// at each bar end, and hover emphasis.
///
/// Drawn by hand rather than with Swift Charts: on macOS 26 a horizontal
/// BarMark insets its category labels into the plot area and squeezes the
/// bars to hairlines, which made the ranked lists hard to read.
struct HBarList: View {
    let rows: [HBarRow]
    var labelWidth: CGFloat = 96
    var barHeight: CGFloat = 8
    var valueWidth: CGFloat = 96
    var rowHeight: CGFloat = HBarList.defaultRowHeight
    var spacing: CGFloat = HBarList.defaultSpacing
    @State private var hovered: String?

    static let defaultRowHeight: CGFloat = 16
    static let defaultSpacing: CGFloat = 10

    /// Height of a list showing `count` rows, for sizing a scroll viewport.
    static func height(rows count: Int,
                       rowHeight: CGFloat = defaultRowHeight,
                       spacing: CGFloat = defaultSpacing) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * rowHeight + CGFloat(count - 1) * spacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows) { row in
                HStack(alignment: .center, spacing: 12) {
                    Text(row.label)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: labelWidth, alignment: .trailing)
                    GeometryReader { geo in
                        let track = max(0, geo.size.width - valueWidth)
                        let frac = min(max(row.fraction, 0), 1)
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
                                .fill(row.color)
                                .frame(width: max(row.value > 0 ? 3 : 0, track * frac), height: barHeight)
                            Text(hovered == row.id ? (row.hoverLabel ?? row.valueLabel) : row.valueLabel)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.inkSecondary)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .frame(height: geo.size.height, alignment: .leading)
                    }
                    .frame(height: barHeight + 6)
                }
                .frame(height: rowHeight)
                .opacity(hovered == nil || hovered == row.id ? 1 : 0.45)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { hovered = row.id } else if hovered == row.id { hovered = nil }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.label): \(row.value)")
            }
        }
    }
}
