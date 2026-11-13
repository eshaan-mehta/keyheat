import Foundation

enum KeyCategory: Int, CaseIterable, Identifiable, Comparable {
    case letter, digit, symbol, editing, modifier, navigation, function, keypad, other

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .letter: return "Letters"
        case .digit: return "Digits"
        case .symbol: return "Symbols"
        case .editing: return "Space & editing"
        case .modifier: return "Modifiers"
        case .navigation: return "Navigation"
        case .function: return "Function row"
        case .keypad: return "Keypad"
        case .other: return "Other"
        }
    }

    static func < (a: KeyCategory, b: KeyCategory) -> Bool { a.rawValue < b.rawValue }
}

enum Hand { case left, right, either }

struct KeyInfo {
    let code: Int
    /// Human-readable name used in charts and tables ("Left Shift", "E", "Space").
    let name: String
    /// What is printed on the key cap ("E", "⇧", "space").
    let legend: String
    /// Small secondary legend (shifted symbol or the word under a modifier symbol).
    let sublegend: String?
    let category: KeyCategory
    let hand: Hand

    /// Function keys and the nav cluster (Insert, Forward Delete, Home, End,
    /// Page Up, Page Down). Escape and the arrows are not counted as special.
    var isSpecial: Bool {
        (category == .function && code != 0x35) || KeyInfo.navCluster.contains(code)
    }

    private static let navCluster: Set<Int> = [0x72, 0x75, 0x73, 0x77, 0x74, 0x79]
}

/// The layout the board is drawn in. Key codes name physical positions
/// (kVK_ANSI_E is the key right of W whatever the input source) and are read
/// as QWERTY typing, so each code stands for a character. Drawing in another
/// layout moves each character's count to where that layout puts it.
enum TypingLayout: String, CaseIterable {
    case qwerty, dvorak

    var title: String {
        switch self {
        case .qwerty: return "QWERTY"
        case .dvorak: return "Dvorak"
        }
    }
}

/// macOS virtual key codes (kVK_*) → key metadata.
enum KeyCodes {
    static func info(_ code: Int, layout: TypingLayout = .qwerty) -> KeyInfo {
        if layout == .dvorak, let k = dvorak[code] { return k }
        if let k = table[code] { return k }
        return KeyInfo(code: code, name: String(format: "Key 0x%02X", code),
                       legend: String(format: "%02X", code), sublegend: nil,
                       category: .other, hand: .either)
    }

    /// Where the character that `code` types on QWERTY sits in `layout`.
    static func position(of code: Int, in layout: TypingLayout) -> Int {
        layout == .dvorak ? dvorakPosition[code] ?? code : code
    }

    static let table: [Int: KeyInfo] = {
        var t: [Int: KeyInfo] = [:]
        func add(_ code: Int, _ name: String, _ legend: String, _ sub: String? = nil,
                 _ cat: KeyCategory, _ hand: Hand) {
            t[code] = KeyInfo(code: code, name: name, legend: legend, sublegend: sub,
                              category: cat, hand: hand)
        }

        // Letters
        for (c, l) in [(0x00,"A"),(0x01,"S"),(0x02,"D"),(0x03,"F"),(0x05,"G"),(0x06,"Z"),
                       (0x07,"X"),(0x08,"C"),(0x09,"V"),(0x0B,"B"),(0x0C,"Q"),(0x0D,"W"),
                       (0x0E,"E"),(0x0F,"R"),(0x11,"T")] {
            add(c, l, l, nil, .letter, .left)
        }
        for (c, l) in [(0x04,"H"),(0x10,"Y"),(0x1F,"O"),(0x20,"U"),(0x22,"I"),(0x23,"P"),
                       (0x25,"L"),(0x26,"J"),(0x28,"K"),(0x2D,"N"),(0x2E,"M")] {
            add(c, l, l, nil, .letter, .right)
        }

        // Digits (sublegend = shifted symbol)
        add(0x12, "1", "1", "!", .digit, .left)
        add(0x13, "2", "2", "@", .digit, .left)
        add(0x14, "3", "3", "#", .digit, .left)
        add(0x15, "4", "4", "$", .digit, .left)
        add(0x17, "5", "5", "%", .digit, .left)
        add(0x16, "6", "6", "^", .digit, .right)
        add(0x1A, "7", "7", "&", .digit, .right)
        add(0x1C, "8", "8", "*", .digit, .right)
        add(0x19, "9", "9", "(", .digit, .right)
        add(0x1D, "0", "0", ")", .digit, .right)

        // Symbols
        add(0x32, "Backtick", "`", "~", .symbol, .left)
        add(0x1B, "Minus", "-", "_", .symbol, .right)
        add(0x18, "Equals", "=", "+", .symbol, .right)
        add(0x21, "Left Bracket", "[", "{", .symbol, .right)
        add(0x1E, "Right Bracket", "]", "}", .symbol, .right)
        add(0x2A, "Backslash", "\\", "|", .symbol, .right)
        add(0x29, "Semicolon", ";", ":", .symbol, .right)
        add(0x27, "Quote", "'", "\"", .symbol, .right)
        add(0x2B, "Comma", ",", "<", .symbol, .right)
        add(0x2F, "Period", ".", ">", .symbol, .right)
        add(0x2C, "Slash", "/", "?", .symbol, .right)
        add(0x0A, "Section", "§", "±", .symbol, .left)

        // Space & editing
        add(0x31, "Space", "", "space", .editing, .either)
        add(0x24, "Return", "⏎", "return", .editing, .right)
        add(0x30, "Tab", "⇥", "tab", .editing, .left)
        add(0x33, "Delete", "⌫", "delete", .editing, .right)
        add(0x75, "Forward Delete", "⌦", "delete", .editing, .right)

        // Modifiers
        add(0x38, "Left Shift", "⇧", "shift", .modifier, .left)
        add(0x3C, "Right Shift", "⇧", "shift", .modifier, .right)
        add(0x3B, "Left Control", "⌃", "control", .modifier, .left)
        add(0x3E, "Right Control", "⌃", "control", .modifier, .right)
        add(0x3A, "Left Option", "⌥", "option", .modifier, .left)
        add(0x3D, "Right Option", "⌥", "option", .modifier, .right)
        add(0x37, "Left Command", "⌘", "command", .modifier, .left)
        add(0x36, "Right Command", "⌘", "command", .modifier, .right)
        add(0x3F, "Fn", "fn", nil, .modifier, .right)
        add(0x39, "Caps Lock", "⇪", "caps lock", .modifier, .left)

        // Function row
        add(0x35, "Escape", "esc", nil, .function, .left)
        for (c, n, h) in [(0x7A,1,Hand.left),(0x78,2,.left),(0x63,3,.left),(0x76,4,.left),
                          (0x60,5,.left),(0x61,6,.left),(0x62,7,.right),(0x64,8,.right),
                          (0x65,9,.right),(0x6D,10,.right),(0x67,11,.right),(0x6F,12,.right),
                          (0x69,13,.right),(0x6B,14,.right),(0x71,15,.right),(0x6A,16,.right),
                          (0x40,17,.right),(0x4F,18,.right),(0x50,19,.right),(0x5A,20,.right)] {
            add(c, "F\(n)", "F\(n)", nil, .function, h)
        }

        // Navigation
        add(0x72, "Insert", "ins", nil, .navigation, .right)
        add(0x73, "Home", "↖", "home", .navigation, .right)
        add(0x77, "End", "↘", "end", .navigation, .right)
        add(0x74, "Page Up", "⇞", "pg up", .navigation, .right)
        add(0x79, "Page Down", "⇟", "pg dn", .navigation, .right)
        add(0x7B, "Left Arrow", "←", nil, .navigation, .right)
        add(0x7C, "Right Arrow", "→", nil, .navigation, .right)
        add(0x7D, "Down Arrow", "↓", nil, .navigation, .right)
        add(0x7E, "Up Arrow", "↑", nil, .navigation, .right)

        // Keypad (not on a TKL board, but counted if an external one is used)
        for (c, n) in [(0x52,0),(0x53,1),(0x54,2),(0x55,3),(0x56,4),(0x57,5),(0x58,6),
                       (0x59,7),(0x5B,8),(0x5C,9)] {
            add(c, "Keypad \(n)", "\(n)", nil, .keypad, .right)
        }
        add(0x41, "Keypad .", ".", nil, .keypad, .right)
        add(0x43, "Keypad *", "*", nil, .keypad, .right)
        add(0x45, "Keypad +", "+", nil, .keypad, .right)
        add(0x47, "Keypad Clear", "clear", nil, .keypad, .right)
        add(0x4B, "Keypad /", "/", nil, .keypad, .right)
        add(0x4C, "Keypad Enter", "enter", nil, .keypad, .right)
        add(0x4E, "Keypad -", "-", nil, .keypad, .right)
        add(0x51, "Keypad =", "=", nil, .keypad, .right)

        // Media / misc
        add(0x48, "Volume Up", "vol+", nil, .other, .right)
        add(0x49, "Volume Down", "vol-", nil, .other, .right)
        add(0x4A, "Mute", "mute", nil, .other, .right)
        add(0x5D, "Yen", "¥", nil, .other, .right)
        add(0x5E, "Underscore (JIS)", "_", nil, .other, .right)
        add(0x66, "Eisu", "英数", nil, .other, .left)
        add(0x68, "Kana", "かな", nil, .other, .right)
        return t
    }()

    /// US Dvorak as physical position → the QWERTY key with the same
    /// character, both as key codes. Dvorak's "E" sits where QWERTY has D,
    /// so kVK_ANSI_D → kVK_ANSI_E.
    private static let dvorakSource: [Int: Int] = {
        // Each QWERTY row next to what the same keys type in Dvorak.
        let rows = [("`1234567890-=", "`1234567890[]"),
                    ("qwertyuiop[]\\", "',.pyfgcrl/=\\"),
                    ("asdfghjkl;'", "aoeuidhtns-"),
                    ("zxcvbnm,./", ";qjkxbmwvz")]
        let byLegend = Dictionary(
            table.values
                .filter { [.letter, .digit, .symbol].contains($0.category) }
                .map { ($0.legend.lowercased(), $0.code) },
            uniquingKeysWith: { first, _ in first })
        var t: [Int: Int] = [:]
        for (qwerty, typed) in rows {
            for (q, d) in zip(qwerty, typed) {
                if let position = byLegend[String(q)], let source = byLegend[String(d)] { t[position] = source }
            }
        }
        return t
    }()

    /// QWERTY key → the position Dvorak puts its character at.
    private static let dvorakPosition = Dictionary(dvorakSource.map { ($0.value, $0.key) },
                                                   uniquingKeysWith: { first, _ in first })

    /// Dvorak keys: each position keeps its code and hand and takes the name,
    /// legends and category of the character Dvorak puts there.
    private static let dvorak: [Int: KeyInfo] = dvorakSource.reduce(into: [:]) { t, entry in
        guard let key = table[entry.key], let char = table[entry.value] else { return }
        t[key.code] = KeyInfo(code: key.code, name: char.name, legend: char.legend,
                              sublegend: char.sublegend, category: char.category, hand: key.hand)
    }
}
