import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case today, week, month, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "7 days"
        case .month: return "30 days"
        case .all: return "All time"
        }
    }

    func start(now: Date, calendar: Calendar = .current) -> Date? {
        let day = calendar.startOfDay(for: now)
        switch self {
        case .today: return day
        case .week: return calendar.date(byAdding: .day, value: -6, to: day)
        case .month: return calendar.date(byAdding: .day, value: -29, to: day)
        case .all: return nil
        }
    }
}

enum HeatScale: String, CaseIterable, Identifiable {
    case linear, sqrt, log
    var id: String { rawValue }

    var title: String {
        switch self {
        case .linear: return "Linear"
        case .sqrt: return "Square root"
        case .log: return "Log"
        }
    }

    /// Map a count onto 0...1 relative to the largest count.
    func normalize(_ count: Int, max: Int) -> Double {
        guard count > 0, max > 0 else { return 0 }
        let ratio = Double(count) / Double(max)
        switch self {
        case .linear: return ratio
        case .sqrt: return ratio.squareRoot()
        case .log: return Foundation.log(Double(count) + 1) / Foundation.log(Double(max) + 1)
        }
    }
}

/// Which end of the per-key ranking the "pressed keys" chart shows.
enum KeyRanking: String, CaseIterable, Identifiable {
    case most, least
    var id: String { rawValue }

    var title: String {
        switch self {
        case .most: return "Most pressed"
        case .least: return "Least pressed"
        }
    }
}

struct KeyCount: Identifiable {
    let info: KeyInfo
    let count: Int
    var id: Int { info.code }
}

struct HourCount: Identifiable {
    let hour: Int      // 0...23, local time
    let count: Int
    var id: Int { hour }
}

struct PeriodCount: Identifiable {
    let start: Date
    let count: Int
    var id: Date { start }
}

/// Everything the dashboard shows, computed for one time range.
struct Stats {
    var total = 0
    var todayTotal = 0                  // always today, regardless of range
    var todayEveryKey = 0               // today across every key, even when filtered
    var allTimeTotal = 0                // everything ever recorded, regardless of range
    var perKey: [KeyCount] = []         // sorted by count, descending
    var countByCode: [Int: Int] = [:]
    var maxCount = 0
    var byHourOfDay: [HourCount] = (0..<24).map { HourCount(hour: $0, count: 0) }
    var timeline: [PeriodCount] = []
    var timelineUnit: Calendar.Component = .day
    /// Period to emphasize in the timeline (today, when the range is Today).
    var timelineHighlight: Date?
    var leftHand = 0
    var rightHand = 0
    var activeHours = 0
    var uniqueKeys = 0
    /// Layout the counts were placed in. `countByCode` and `perKey` are keyed by
    /// position on this layout's board.
    var layout = TypingLayout.qwerty
    /// Keys drawn on the board: all of them, or just letters and punctuation.
    var boardKeys = KeyboardLayout.keys
    var firstDate: Date?

    var peakHour: HourCount? {
        guard let m = byHourOfDay.max(by: { $0.count < $1.count }), m.count > 0 else { return nil }
        return m
    }
    var topKey: KeyCount? { perKey.first }

    /// Every pressed key, ordered from the chosen end of the ranking. Ties are
    /// broken by name so the order is stable between refreshes.
    func ranked(_ ranking: KeyRanking, includeSpecial: Bool) -> [KeyCount] {
        let keys = includeSpecial ? perKey : perKey.filter { !$0.info.isSpecial }
        switch ranking {
        case .most:
            return keys
        case .least:
            return keys.sorted { a, b in
                a.count != b.count ? a.count < b.count : a.info.name < b.info.name
            }
        }
    }

    /// Keys drawn on the board with no presses in this range.
    func unpressedOnBoard(includeSpecial: Bool) -> Int {
        boardKeys.filter { key in
            (countByCode[key.code] ?? 0) == 0 && (includeSpecial || !KeyCodes.info(key.code).isSpecial)
        }.count
    }

    func rank(of code: Int) -> Int? {
        perKey.firstIndex { $0.info.code == code }.map { $0 + 1 }
    }

    func share(_ count: Int) -> Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    /// Recorded key codes are read as QWERTY characters, and each character's
    /// count is placed where `layout` puts it, so names, positions and hands
    /// all follow the layout.
    /// `lettersAndPunctuation` drops every other key before counting, so
    /// totals, shares, the timeline and hand balance describe those keys alone.
    static func compute(buckets: KeyStore.Buckets, range: TimeRange, layout: TypingLayout,
                        lettersAndPunctuation: Bool, now: Date = Date()) -> Stats {
        let cal = Calendar.current
        var s = Stats()
        s.layout = layout
        let startOfToday = cal.startOfDay(for: now)
        let rangeStart = range.start(now: now)

        // The timeline is always daily (weekly for long histories). Today's
        // range shows two weeks of context so today can be compared.
        let timelineWindowStart: Date? = {
            switch range {
            case .today: return cal.date(byAdding: .day, value: -13, to: startOfToday)
            case .week, .month: return rangeStart
            case .all: return nil
            }
        }()

        var counts: [Int: Int] = [:]
        var hourOfDay = [Int](repeating: 0, count: 24)
        var perBucket: [Int: Int] = [:]
        var timelineBuckets: [Int: Int] = [:]
        var minHour = Int.max
        var minHourAll = Int.max

        // Letters plus the punctuation typed among them. Which physical keys
        // those are depends on the layout.
        let punctuation: Set<String> = [",", ".", "/", ";", "'"]
        let textKeys = Set(KeyCodes.table.keys.filter { code in
            let info = KeyCodes.info(code, layout: layout)
            return info.category == .letter || (info.category == .symbol && punctuation.contains(info.legend))
        })
        if lettersAndPunctuation { s.boardKeys = KeyboardLayout.keys.filter { textKeys.contains($0.code) } }

        for (hour, recorded) in buckets {
            let bucketEnd = TimeInterval(hour + 1) * 3600
            let isToday = bucketEnd > startOfToday.timeIntervalSince1970
            if isToday { s.todayEveryKey += recorded.values.reduce(0, +) }
            // Key code → position in the layout, dropping keys outside the filter.
            var keys = recorded
            if layout != .qwerty || lettersAndPunctuation {
                keys = [:]
                for (code, n) in recorded {
                    let position = KeyCodes.position(of: code, in: layout)
                    if !lettersAndPunctuation || textKeys.contains(position) { keys[position, default: 0] += n }
                }
            }
            if keys.isEmpty { continue }

            let bucketTotal = keys.values.reduce(0, +)
            s.allTimeTotal += bucketTotal
            minHourAll = min(minHourAll, hour)
            if isToday { s.todayTotal += bucketTotal }
            if timelineWindowStart.map({ bucketEnd > $0.timeIntervalSince1970 }) ?? true {
                timelineBuckets[hour] = bucketTotal
            }
            if let rs = rangeStart, bucketEnd <= rs.timeIntervalSince1970 { continue }

            perBucket[hour] = bucketTotal
            minHour = min(minHour, hour)
            let date = Date(timeIntervalSince1970: TimeInterval(hour) * 3600)
            hourOfDay[cal.component(.hour, from: date)] += bucketTotal
            for (code, n) in keys { counts[code, default: 0] += n }
        }

        s.countByCode = counts
        s.total = counts.values.reduce(0, +)
        s.maxCount = counts.values.max() ?? 0
        s.uniqueKeys = counts.count
        s.activeHours = perBucket.count
        s.byHourOfDay = hourOfDay.enumerated().map { HourCount(hour: $0.offset, count: $0.element) }
        if minHour != Int.max {
            s.firstDate = Date(timeIntervalSince1970: TimeInterval(minHour) * 3600)
        }

        s.perKey = counts
            .map { KeyCount(info: KeyCodes.info($0.key, layout: layout), count: $0.value) }
            .sorted { a, b in
                a.count != b.count ? a.count > b.count : a.info.name < b.info.name
            }

        // Hands
        var left = 0, right = 0
        for (code, n) in counts {
            switch KeyCodes.info(code).hand {
            case .left: left += n
            case .right: right += n
            case .either: break
            }
        }
        s.leftHand = left
        s.rightHand = right

        // Timeline periods, zero-filled from the window start to now.
        var unit: Calendar.Component = .day
        let timelineStart: Date
        if let ws = timelineWindowStart {
            timelineStart = ws
        } else if minHourAll != Int.max {
            let first = Date(timeIntervalSince1970: TimeInterval(minHourAll) * 3600)
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: first), to: startOfToday).day ?? 0
            unit = days > 120 ? .weekOfYear : .day
            timelineStart = cal.dateInterval(of: unit, for: first)?.start ?? first
        } else {
            timelineStart = startOfToday
        }
        var periodTotals: [Date: Int] = [:]
        for (hour, n) in timelineBuckets {
            let d = Date(timeIntervalSince1970: TimeInterval(hour) * 3600)
            if let start = cal.dateInterval(of: unit, for: d)?.start {
                periodTotals[start, default: 0] += n
            }
        }
        var timeline: [PeriodCount] = []
        var cursor = cal.dateInterval(of: unit, for: timelineStart)?.start ?? timelineStart
        var steps = 0
        while cursor <= now && steps < 2000 {
            timeline.append(PeriodCount(start: cursor, count: periodTotals[cursor] ?? 0))
            guard let next = cal.date(byAdding: unit, value: 1, to: cursor) else { break }
            cursor = next
            steps += 1
        }
        s.timelineHighlight = range == .today ? startOfToday : nil
        s.timeline = timeline
        s.timelineUnit = unit
        return s
    }
}
