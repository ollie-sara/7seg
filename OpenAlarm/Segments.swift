import SwiftUI

/// Unlit-LCD palette. Light is a reflective grey-green LCD; dark is a negative LCD.
extension UIColor {
    static let lcd = UIColor(light: 0xC7CCB6, dark: 0x0D0F0C)
    static let ink = UIColor(light: 0x1A1D15, dark: 0xD0D6C3)
    /// Secondary text. Plain `.secondary` (ink at half opacity) fails contrast on the LCD ground.
    static let ink2 = UIColor(light: 0x474C3D, dark: 0x8A917D)
    /// Delete actions only: a brick red, like the red legends printed on old LCD faces.
    static let deleteRed = UIColor(light: 0x8E2618, dark: 0xCC5A45)

    private convenience init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) }
    }
}

extension Color {
    static let lcd = Color(uiColor: .lcd)
    static let ink = Color(uiColor: .ink)
    static let ink2 = Color(uiColor: .ink2)
    static let deleteRed = Color(uiColor: .deleteRed)
    /// Nightstand digits: red channel only, the least light an OLED can emit for a readable face.
    static let nightRed = Color(red: 0.6, green: 0, blue: 0)
}

/// 7-segment glyph geometry, in units of the digit height.
enum Segments {
    private static let map: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
        "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g", " ": "",
    ]
    private static let digitWidth = 0.52, thickness = 0.14
    private static let spacing = thickness * 0.75, colonWidth = thickness * 1.6

    static func width(_ text: String) -> CGFloat {
        let chars = text.map { $0 == ":" ? colonWidth : digitWidth }
        return chars.reduce(0, +) + spacing * Double(max(chars.count - 1, 0))
    }

    /// Lit segments (and colons) when `lit`, otherwise the unlit ghost segments.
    static func path(_ text: String, in rect: CGRect, lit: Bool) -> Path {
        let scale = min(rect.height, rect.width / width(text))
        var x = rect.minX + (rect.width - width(text) * scale) / 2
        let y = rect.midY - scale / 2
        var path = Path()
        func add(_ points: [(Double, Double)], at dx: Double) {
            path.addLines(points.map { CGPoint(x: x + (dx + $0.0) * scale, y: y + $0.1 * scale) })
            path.closeSubpath()
        }
        for char in text {
            if char == ":" {
                if lit {
                    let t = thickness, cx = colonWidth / 2
                    for cy in [0.3, 0.7] {
                        add([(cx - t / 2, cy - t / 2), (cx + t / 2, cy - t / 2), (cx + t / 2, cy + t / 2), (cx - t / 2, cy + t / 2)], at: 0)
                    }
                }
                x += (colonWidth + spacing) * scale
                continue
            }
            let on = map[char] ?? ""
            for (name, points) in polygons where on.contains(name) == lit {
                add(points, at: 0)
            }
            x += (digitWidth + spacing) * scale
        }
        return path
    }

    private static let polygons: [(Character, [(Double, Double)])] = {
        let t = thickness, h = t / 2, gap = t * 0.14, w = digitWidth
        func horizontal(_ y: Double) -> [(Double, Double)] {
            let x0 = h + gap, x1 = w - h - gap
            return [(x0, y), (x0 + h, y - h), (x1 - h, y - h), (x1, y), (x1 - h, y + h), (x0 + h, y + h)]
        }
        func vertical(_ x: Double, _ y0: Double, _ y1: Double) -> [(Double, Double)] {
            [(x, y0), (x + h, y0 + h), (x + h, y1 - h), (x, y1), (x - h, y1 - h), (x - h, y0 + h)]
        }
        let top = h, mid = 0.5, bottom = 1 - h, left = h, right = w - h
        return [
            ("a", horizontal(top)), ("g", horizontal(mid)), ("d", horizontal(bottom)),
            ("f", vertical(left, top + gap, mid - gap)), ("b", vertical(right, top + gap, mid - gap)),
            ("e", vertical(left, mid + gap, bottom - gap)), ("c", vertical(right, mid + gap, bottom - gap)),
        ]
    }()

    /// The same time as plain text for legends: "06:30" or "6:30 AM".
    static func label(hour: Int, minute: Int) -> String {
        let clock = clock(hour: hour, minute: minute)
        return clock.digits.trimmingCharacters(in: .whitespaces) + (clock.period.map { " \($0)" } ?? "")
    }

    static func label(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return label(hour: parts.hour!, minute: parts.minute!)
    }

    /// Clock digits for the display: "06:30" on a 24-hour locale, " 6:30" plus the AM/PM symbol on a 12-hour one.
    static func clock(hour: Int, minute: Int, locale: Locale = .current) -> (digits: String, period: String?) {
        let twelveHour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)?.contains("a") == true
        guard twelveHour else { return (String(format: "%02d:%02d", hour, minute), nil) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        let digits = (h12 < 10 ? " " : "") + "\(h12):" + String(format: "%02d", minute)
        return (digits, hour < 12 ? calendar.amSymbol : calendar.pmSymbol)
    }
}

private struct SegmentShape: Shape {
    let text: String
    let lit: Bool
    func path(in rect: CGRect) -> Path { Segments.path(text, in: rect, lit: lit) }
}

/// Segment text in the current foreground style, with faint unlit segments behind it unless `ghost` is false.
struct SegmentText: View {
    let text: String
    var ghost = true

    var body: some View {
        ZStack {
            if ghost { SegmentShape(text: text, lit: false).fill(.foreground.opacity(0.075)) }
            SegmentShape(text: text, lit: true).fill(.foreground)
        }
        .aspectRatio(Segments.width(text), contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// A time of day as LCD digits, with the AM/PM legend on 12-hour locales.
struct SegmentClock: View {
    let hour: Int
    let minute: Int
    var ghost = true

    init(hour: Int, minute: Int, ghost: Bool = true) {
        self.hour = hour
        self.minute = minute
        self.ghost = ghost
    }

    init(_ date: Date, ghost: Bool = true) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour!, minute: parts.minute!, ghost: ghost)
    }

    var body: some View {
        let clock = Segments.clock(hour: hour, minute: minute)
        HStack(alignment: .top, spacing: 6) {
            SegmentText(text: clock.digits, ghost: ghost)
            if let period = clock.period { Legend(period) }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(Calendar.current.date(from: DateComponents(hour: hour, minute: minute))!, style: .time))
    }
}

/// Small printed LCD annunciator text: ONCE, AL, AM/PM.
struct Legend: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.8)
    }
}
