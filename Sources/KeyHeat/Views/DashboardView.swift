import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @State private var hoveredKey: Int?
    @State private var confirmReset = false

    private let gutter: CGFloat = 36

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 28)
                if state.tracking == .noPermission {
                    PermissionBanner().padding(.bottom, 28)
                }
                controls
                    .padding(.bottom, 36)
                statRow
                    .padding(.bottom, 44)
                heatmap
                    .padding(.bottom, 44)
                Hairline()
                    .padding(.bottom, 36)
                HStack(alignment: .top, spacing: 56) {
                    VStack(alignment: .leading, spacing: 20) {
                        rankedKeysHeader
                        RankedKeysChart(keys: rankedKeys, total: state.stats.total, scale: state.scale,
                                        visibleRows: visibleRankedRows)
                            // Start from the top again when the order or filter changes.
                            .id("\(state.keyRanking.rawValue)-\(state.showSpecialKeys)-\(state.lettersAndPunctuation)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: timelineTitle, subtitle: timelineSubtitle)
                        TimelineChart(periods: state.stats.timeline, unit: state.stats.timelineUnit,
                                      highlight: state.stats.timelineHighlight)
                        Spacer().frame(height: 16)
                        SectionHeader(title: "Hand balance", subtitle: "Presses by the hand that reaches the key.")
                        HandBalanceView(left: state.stats.leftHand, right: state.stats.rightHand)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 44)
                Hairline()
                    .padding(.bottom, 16)
                footer
            }
            .padding(.horizontal, gutter)
            .padding(.vertical, 32)
        }
        .background(Palette.background)
        .confirmationDialog("Delete all recorded key counts?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { state.resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the whole history from disk. It cannot be undone.")
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("KeyHeat").font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.ink)
            TrackingStatus(state: state.tracking)
            Spacer()
            if state.tracking != .noPermission {
                QuietButton(title: state.tracking == .paused ? "Resume tracking" : "Pause tracking") { state.togglePause() }
            }
            Menu {
                Button("Export CSV…") { state.exportCSV() }
                Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                Divider()
                Button("Reset all data…", role: .destructive) { confirmReset = true }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(Palette.inkSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var controls: some View {
        HStack(alignment: .firstTextBaseline) {
            TextSegments(options: TimeRange.allCases.map { ($0, $0.title) }, selection: $state.range, size: 14)
            Spacer()
            TextSegments(options: HeatScale.allCases.map { ($0, $0.title) }, selection: $state.scale, size: 12)
            TextSegments(options: TypingLayout.allCases.map { ($0, $0.title) }, selection: $state.typingLayout, size: 12)
                .help("Draw your typing on a QWERTY or Dvorak board. Presses are read as QWERTY, and each character's count moves to where the layout puts it.")
                .padding(.leading, 28)
            Toggle("Letters & punctuation", isOn: $state.lettersAndPunctuation)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 8)
                .help("Show only the letters and , . / ; ' keys. Totals, shares and charts then count those keys alone.")
            Toggle("Counts", isOn: $state.showCounts)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 8)
        }
    }

    private var statRow: some View {
        let s = state.stats
        return HStack(alignment: .top, spacing: 24) {
            Stat(value: s.total.formatted(),
                 label: "presses · \(state.range.title.lowercased())",
                 detail: s.activeHours > 0 ? "over \(s.activeHours) active hour\(s.activeHours == 1 ? "" : "s")" : nil)
            if state.range == .today {
                Stat(value: s.allTimeTotal.formatted(), label: "presses · all time")
            } else {
                Stat(value: s.todayTotal.formatted(), label: "presses · today")
            }
            Stat(value: s.topKey?.info.name ?? "—",
                 label: "most pressed",
                 detail: s.topKey.map { "\($0.count.formatted()) · \(Fmt.percent(s.share($0.count)))" })
            Stat(value: s.peakHour.map { Fmt.hourLabel($0.hour) } ?? "—",
                 label: "peak hour",
                 detail: s.peakHour.map { "\($0.count.formatted()) presses" })
            Stat(value: s.activeHours > 0 ? (s.total / s.activeHours).formatted() : "—",
                 label: "per active hour")
            Stat(value: "\(s.uniqueKeys)",
                 label: "keys used",
                 detail: "of \(s.boardKeys.count) on the board")
        }
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeatmapView(stats: state.stats, scale: state.scale,
                        showCounts: state.showCounts, hovered: $hoveredKey)
                .frame(maxWidth: .infinity)
            HStack {
                KeyDetailStrip(hovered: hoveredKey, stats: state.stats,
                               lettersAndPunctuation: state.lettersAndPunctuation)
                HeatLegend(maxCount: state.stats.maxCount, scale: state.scale)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Counts are stored per key and hour in \(state.store.url.path). Key order is never recorded.")
            Spacer()
            if let first = state.stats.firstDate {
                Text("Data since \(first.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Palette.muted)
    }

    private let visibleRankedRows = 15

    private var rankedKeys: [KeyCount] {
        state.stats.ranked(state.keyRanking, includeSpecial: state.showSpecialKeys)
    }

    /// The section title doubles as the Most / Least toggle, in the same
    /// text-only style as the range and scale controls.
    private var rankedKeysHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                TextSegments(options: KeyRanking.allCases.map { ($0, $0.title) }, selection: $state.keyRanking, size: 15)
                Spacer()
                // None of these is a special key, so the filter has nothing to do.
                if !state.lettersAndPunctuation {
                    Toggle("Special keys", isOn: $state.showSpecialKeys)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .help("Function keys, Insert, Forward Delete, Home, End, Page Up and Page Down")
                }
            }
            Text(rankedKeysSubtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
    }

    private var rankedKeysSubtitle: String {
        let keys = rankedKeys
        guard !keys.isEmpty else { return "Ranked by presses in this range." }
        var parts = ["\(keys.count) key\(keys.count == 1 ? "" : "s"), \(state.keyRanking == .most ? "most" : "least") pressed first."]
        if state.keyRanking == .least {
            let unpressed = state.stats.unpressedOnBoard(includeSpecial: state.showSpecialKeys)
            if unpressed > 0 { parts.append("\(unpressed) \(unpressed == 1 ? "was" : "were") never pressed.") }
        }
        if keys.count > visibleRankedRows { parts.append("Scroll for more.") }
        parts.append("Hover for share.")
        return parts.joined(separator: " ")
    }

    private var timelineTitle: String {
        state.stats.timelineUnit == .weekOfYear ? "Presses per week" : "Presses per day"
    }

    private var timelineSubtitle: String {
        switch state.range {
        case .today: return "Last 14 days. Today in blue."
        case .week: return "Daily totals for the last 7 days."
        case .month: return "Daily totals for the last 30 days."
        case .all: return "Everything recorded so far."
        }
    }
}

struct TrackingStatus: View {
    let state: TrackingState

    var body: some View {
        let (color, text): (Color, String) = {
            switch state {
            case .active: return (Palette.good, "Tracking")
            case .paused: return (Palette.muted, "Paused")
            case .noPermission: return (Palette.accentRed, "No permission")
            }
        }()
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.system(size: 12)).foregroundStyle(Palette.inkSecondary)
        }
    }
}

struct PermissionBanner: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Input Monitoring permission is needed").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                Text("KeyHeat counts key presses system-wide, which macOS gates behind Privacy & Security → Input Monitoring. Turn on KeyHeat there. Tracking starts on its own once it is allowed; if it does not within a few seconds, relaunch.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            QuietButton(title: "Open System Settings") { state.openInputMonitoringSettings() }
            QuietButton(title: "Relaunch") { state.relaunch() }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.wash))
    }
}
