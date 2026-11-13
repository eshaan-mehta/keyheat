import Foundation

struct LayoutKey: Identifiable {
    let code: Int
    let x: Double   // in key units
    let y: Double
    let w: Double
    var id: Int { code }
}

/// Tenkeyless (87-key) Mac layout: function row, main block, nav cluster, arrows.
/// Bottom row is the Mac order used by TKL boards like the Keychron K8/Q3:
/// control · option · command · space · command · option · fn · control.
enum KeyboardLayout {
    static let width: Double = 18.25
    static let height: Double = 6.5

    static let keys: [LayoutKey] = {
        var keys: [LayoutKey] = []
        let gap = -1
        func row(_ y: Double, _ items: [(Int, Double)]) {
            var x = 0.0
            for (code, w) in items {
                if code != gap { keys.append(LayoutKey(code: code, x: x, y: y, w: w)) }
                x += w
            }
        }
        // Function row
        row(0, [(0x35,1),(gap,1),
                (0x7A,1),(0x78,1),(0x63,1),(0x76,1),(gap,0.5),
                (0x60,1),(0x61,1),(0x62,1),(0x64,1),(gap,0.5),
                (0x65,1),(0x6D,1),(0x67,1),(0x6F,1),(gap,0.25),
                (0x69,1),(0x6B,1),(0x71,1)])
        // Number row
        row(1.5, [(0x32,1),(0x12,1),(0x13,1),(0x14,1),(0x15,1),(0x17,1),(0x16,1),(0x1A,1),
                  (0x1C,1),(0x19,1),(0x1D,1),(0x1B,1),(0x18,1),(0x33,2),(gap,0.25),
                  (0x72,1),(0x73,1),(0x74,1)])
        // Top letter row
        row(2.5, [(0x30,1.5),(0x0C,1),(0x0D,1),(0x0E,1),(0x0F,1),(0x11,1),(0x10,1),(0x20,1),
                  (0x22,1),(0x1F,1),(0x23,1),(0x21,1),(0x1E,1),(0x2A,1.5),(gap,0.25),
                  (0x75,1),(0x77,1),(0x79,1)])
        // Home row
        row(3.5, [(0x39,1.75),(0x00,1),(0x01,1),(0x02,1),(0x03,1),(0x05,1),(0x04,1),(0x26,1),
                  (0x28,1),(0x25,1),(0x29,1),(0x27,1),(0x24,2.25)])
        // Bottom letter row
        row(4.5, [(0x38,2.25),(0x06,1),(0x07,1),(0x08,1),(0x09,1),(0x0B,1),(0x2D,1),(0x2E,1),
                  (0x2B,1),(0x2F,1),(0x2C,1),(0x3C,2.75),(gap,1.25),(0x7E,1)])
        // Modifier row
        row(5.5, [(0x3B,1.25),(0x3A,1.25),(0x37,1.25),(0x31,6.25),(0x36,1.25),(0x3D,1.25),
                  (0x3F,1.25),(0x3E,1.25),(gap,0.25),(0x7B,1),(0x7D,1),(0x7C,1)])
        return keys
    }()

    static let codes: Set<Int> = Set(keys.map(\.code))

    /// Smallest rectangle around `keys`, in key units. The whole board if empty.
    static func bounds(of keys: [LayoutKey]) -> CGRect {
        guard let minX = keys.map(\.x).min(), let maxX = keys.map({ $0.x + $0.w }).max(),
              let minY = keys.map(\.y).min(), let maxY = keys.map({ $0.y + 1 }).max() else {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
