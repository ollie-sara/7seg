import SwiftUI

/// Snooze and Stop live only here, never on the lock screen.
struct RingingView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let alarm = store.ringing
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: 32) {
                    face(alarm)
                    buttons(alarm).frame(maxWidth: 320)
                }
            } else {
                VStack(spacing: 24) {
                    face(alarm)
                    buttons(alarm)
                }
            }
        }
        .padding(24)
        .foregroundStyle(Color.ink)
        .background(Color.lcd)
    }

    private func face(_ alarm: AlarmItem?) -> some View {
        VStack(spacing: 20) {
            if let alarm {
                Legend("AL \(Segments.label(hour: alarm.hour, minute: alarm.minute))")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            // Flashes like an alarming LCD clock; steady under Reduce Motion.
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let lit = reduceMotion || Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                SegmentClock(context.date)
                    .opacity(lit ? 1 : 0.15)
            }
            .frame(maxHeight: 150)
            Text(alarm?.title ?? "Alarm")
                .font(.title.weight(.semibold))
            Spacer(minLength: 0)
        }
    }

    private func buttons(_ alarm: AlarmItem?) -> some View {
        VStack(spacing: 12) {
            if store.canSnooze, let alarm {
                Button { store.snooze() } label: {
                    VStack(spacing: 2) {
                        Text("Snooze \(alarm.snoozeMinutes) min")
                        if let left = snoozesLeft(alarm) {
                            Text(left).font(.subheadline).foregroundStyle(Color.ink2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.ink, lineWidth: 2) }
                    .contentShape(.rect)
                }
            }
            Button { store.stop() } label: {
                Text("Stop")
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .foregroundStyle(Color.lcd)
                    .background(Color.ink, in: .rect(cornerRadius: 6))
            }
        }
        .buttonStyle(.plain)
        .font(.title2.weight(.semibold))
    }

    private func snoozesLeft(_ alarm: AlarmItem) -> String? {
        guard let max = alarm.maxSnoozes, let used = store.session?.snoozes else { return nil }
        return "\(max - used) of \(max) left"
    }
}
