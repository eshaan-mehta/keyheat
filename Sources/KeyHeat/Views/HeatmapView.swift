import SwiftUI

struct HeatmapView: View {
    let stats: Stats
    let scale: HeatScale
    let showCounts: Bool
    @Binding var hovered: Int?

    var body: some View {
        let keys = stats.boardKeys
        let box = KeyboardLayout.bounds(of: keys)
        GeometryReader { geo in
            // Keys are sized against the full board's width, so showing part
            // of the board crops it instead of zooming in.
            let unit = min(geo.size.width / KeyboardLayout.width, geo.size.height / box.height)
            let originX = (geo.size.width - unit * box.width) / 2 - unit * box.minX
            let originY = (geo.size.height - unit * box.height) / 2 - unit * box.minY
            ZStack(alignment: .topLeading) {
                ForEach(keys) { key in
                    let count = stats.countByCode[key.code] ?? 0
                    KeyCapView(info: KeyCodes.info(key.code, layout: stats.layout),
                               count: count,
                               t: scale.normalize(count, max: stats.maxCount),
                               unit: unit,
                               isHovered: hovered == key.code,
                               showCount: showCounts)
                        .frame(width: key.w * unit, height: unit)
                        .offset(x: originX + key.x * unit, y: originY + key.y * unit)
                        .onHover { inside in
                            if inside { hovered = key.code } else if hovered == key.code { hovered = nil }
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(KeyboardLayout.width / box.height, contentMode: .fit)
    }
}

private struct KeyCapView: View {
    let info: KeyInfo
    let count: Int
    let t: Double
    let unit: CGFloat
    let isHovered: Bool
    let showCount: Bool

    var body: some View {
        let heat = count > 0 ? Heat.sample(t) : nil
        let fill: Color = heat?.color ?? Palette.background
        let ink: Color = {
            guard let heat else { return Palette.muted }
            return heat.lightness > 0.58 ? Palette.ink : .white
        }()
        let radius = unit * 0.14
        let isWord = info.legend.count > 1

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(isHovered ? Palette.ink : Palette.keyBorder, lineWidth: isHovered ? 1.5 : 1)
            VStack(spacing: unit * 0.02) {
                if let sub = info.sublegend, unit >= 30 {
                    Text(sub).font(.system(size: unit * 0.17)).opacity(0.8)
                }
                if !info.legend.isEmpty {
                    Text(info.legend)
                        .font(.system(size: isWord ? unit * 0.2 : unit * 0.32, weight: .medium))
                }
                if showCount, count > 0, unit >= 30 {
                    Text(count.formatted()).font(.system(size: unit * 0.15)).opacity(0.85)
                }
            }
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 2)
        }
        .padding(1.5)   // 3pt of white between adjacent keys
        .contentShape(Rectangle())
        .help("\(info.name): \(count.formatted()) presses")
        .accessibilityLabel("\(info.name), \(count) presses")
    }
}

/// Fixed detail line under the keyboard; every value is reachable without a tooltip.
struct KeyDetailStrip: View {
    let hovered: Int?
    let stats: Stats
    let lettersAndPunctuation: Bool

    var body: some View {
        HStack(spacing: 14) {
            if let code = hovered {
                let info = KeyCodes.info(code, layout: stats.layout)
                let count = stats.countByCode[code] ?? 0
                Text(info.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                Text("\(count.formatted()) presses").foregroundStyle(Palette.inkSecondary)
                Text(Fmt.percent(stats.share(count)) + (lettersAndPunctuation ? " of letters & punctuation" : " of all")).foregroundStyle(Palette.inkSecondary)
                if let r = stats.rank(of: code) {
                    Text("#\(r) of \(stats.uniqueKeys)").foregroundStyle(Palette.inkSecondary)
                }
                Text(info.category.name).foregroundStyle(Palette.muted)
            } else {
                Text("Hover a key for its count, share and rank.").foregroundStyle(Palette.muted)
            }
            Spacer()
        }
        .font(.system(size: 13))
        .frame(height: 20)
    }
}

struct HeatLegend: View {
    let maxCount: Int
    let scale: HeatScale

    var body: some View {
        HStack(spacing: 8) {
            Text("0").font(.system(size: 12)).foregroundStyle(Palette.muted)
            RoundedRectangle(cornerRadius: 3)
                .fill(Heat.gradient)
                .frame(width: 140, height: 6)
            Text(maxCount.formatted()).font(.system(size: 12)).foregroundStyle(Palette.muted)
            Text("· \(scale.title.lowercased()) scale").font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
    }
}
