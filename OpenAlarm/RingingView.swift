import SwiftUI

/// Snooze and Stop live only here, never on the lock screen.
struct RingingView: View {
    @Environment(AlarmStore.self) private var store

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(Date.now, style: .time)
                .font(.system(size: 80, weight: .thin, design: .rounded))
            Text(store.ringing?.title ?? "Alarm")
                .font(.title)
            Spacer()
            if store.canSnooze, let alarm = store.ringing {
                Button { store.snooze() } label: {
                    Text("Snooze \(alarm.snoozeMinutes) min").frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.bordered)
            }
            Button { store.stop() } label: {
                Text("Stop").frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .font(.title2.weight(.semibold))
        .padding(24)
    }
}
