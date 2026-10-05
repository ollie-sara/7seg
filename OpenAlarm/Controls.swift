import SwiftUI

/// LCD switch: a hollow ink cell when off, solid ink when on, with a square knob that slides across.
struct LCDToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        LCDSwitch(configuration: configuration)
    }
}

private struct LCDSwitch: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ToggleStyleConfiguration

    var body: some View {
        let on = configuration.isOn
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: on ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(on ? Color.ink : .clear)
                    .strokeBorder(Color.ink, lineWidth: 1.5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(on ? Color.lcd : Color.ink)
                    .padding(5)
                    .frame(width: 30)
            }
            .frame(width: 52, height: 30)
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: on)
            .contentShape(.rect)
            .onTapGesture { configuration.isOn.toggle() }
            .sensoryFeedback(.selection, trigger: on)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

/// LCD bar graph for a 10–100 % level: ten cells growing toward loud, inked up to the value. Tap or drag to set.
struct LevelBar: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(1...10, id: \.self) { cell in
                    Rectangle()
                        .fill(.foreground.opacity(cell <= Int((value * 10).rounded()) ? 1 : 0.075))
                        .frame(height: geo.size.height * (0.4 + 0.06 * Double(cell)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = min(max((drag.location.x / geo.size.width * 10).rounded(.up), 1), 10) / 10
            })
        }
        .frame(height: 28)
        .accessibilityRepresentation { Slider(value: $value, in: 0.1...1, step: 0.1) }
    }
}

/// Time setter: two flickable wheels of segment digits, hours and minutes, snapping to the center row.
struct TimeSetter: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @ScaledMetric(relativeTo: .largeTitle) private var digitHeight = 72

    var body: some View {
        let height = min(digitHeight, 110)
        let period = Segments.clock(hour: hour, minute: minute).period
        let time = Calendar.current.date(from: DateComponents(hour: hour, minute: minute))!
        HStack(spacing: height * 0.105) {
            DigitWheel(value: $hour, count: 24, height: height, name: "Hour", time: time) {
                String(Segments.clock(hour: $0, minute: 0).digits.prefix { $0 != ":" })
            }
            SegmentText(text: ":").frame(height: height)
            DigitWheel(value: $minute, count: 60, height: height, name: "Minute", time: time) {
                String(format: "%02d", $0)
            }
            if let period {
                Legend(period).frame(height: height, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: hour * 60 + minute)
    }
}

/// One looping wheel: the range repeated `cycles` times, starting in the middle, so it scrolls either way.
/// The window is 2.2 rows tall; row n sits centered at scroll offset `n * row - inset`.
private struct DigitWheel: View {
    @Binding var value: Int
    let count: Int
    let height: CGFloat
    let name: String
    let time: Date
    let text: (Int) -> String
    @State private var scroll: ScrollPosition
    @State private var index: Int
    private static let cycles = 40

    private var row: CGFloat { height * 1.25 }
    private var inset: CGFloat { row * 0.6 }

    init(value: Binding<Int>, count: Int, height: CGFloat, name: String, time: Date, text: @escaping (Int) -> String) {
        _value = value
        self.count = count
        self.height = height
        self.name = name
        self.time = time
        self.text = text
        let start = count * Self.cycles / 2 + value.wrappedValue
        _index = State(initialValue: start)
        _scroll = State(initialValue: ScrollPosition(y: CGFloat(start) * height * 1.25 - height * 0.75))
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(0..<count * Self.cycles, id: \.self) { id in
                    SegmentText(text: text(id % count))
                        .frame(height: height)
                        .frame(height: row)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scroll)
        .scrollTargetBehavior(RowSnap(row: row, inset: inset))
        .frame(width: Segments.width("88") * height, height: row * 2.2)
        // Rows above and below fade out, like digits printed beyond the window.
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3),
                                     .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .onScrollGeometryChange(for: Int.self) { Int((($0.contentOffset.y + inset) / row).rounded()) } action: { _, n in
            index = n
            value = n % count
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(time.formatted(date: .omitted, time: .shortened))
        .accessibilityAdjustableAction { direction in
            withAnimation { scroll.scrollTo(y: CGFloat(index + (direction == .increment ? 1 : -1)) * row - inset) }
        }
    }
}

/// Snaps the scroll offset so a row lands centered in the wheel window.
private struct RowSnap: ScrollTargetBehavior {
    let row: CGFloat
    let inset: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = ((target.rect.origin.y + inset) / row).rounded() * row - inset
    }
}

/// Solid ink button with ground-colored content, 6 pt corners. Replaces the glass toolbar buttons.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.lcd)
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 36)
            .background(Color.ink.opacity(configuration.isPressed ? 0.7 : 1), in: .rect(cornerRadius: 6))
    }
}

/// Ink outline on the ground, 6 pt corners: the secondary partner of `InkButtonStyle`.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 36)
            .background(Color.ink.opacity(configuration.isPressed ? 0.12 : 0), in: .rect(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.ink, lineWidth: 1.5) }
    }
}

extension View {
    /// A `Form` on the bare ground: no grouped cards, the 16 pt gutter of the list, and sections far enough
    /// apart that each header reads with its own rows.
    func sheetForm() -> some View {
        scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .listSectionSpacing(28)
            .background(Color.lcd)
    }
}
