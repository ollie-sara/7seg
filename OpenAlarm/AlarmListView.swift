import SwiftUI

struct AlarmListView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var editing: AlarmItem?

    var body: some View {
        NavigationStack {
            List {
                if store.authorization == .denied {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Alarms won't ring", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text("OpenAlarm isn't allowed to schedule alarms. Turn on Alarms in Settings.")
                            Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                        }
                    }
                }
                ForEach(store.sortedAlarms) { alarm in
                    AlarmRow(alarm: alarm)
                        .contentShape(.rect)
                        .onTapGesture { editing = alarm }
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.delete(alarm.id) }
                        }
                }
            }
            .overlay {
                if store.alarms.isEmpty {
                    ContentUnavailableView("No Alarms", systemImage: "alarm", description: Text("Tap + to add one."))
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                Button("Add Alarm", systemImage: "plus") { editing = AlarmItem() }
            }
            .sheet(item: $editing) { alarm in
                AlarmEditor(alarm: alarm, isNew: store.alarm(alarm.id) == nil)
            }
        }
    }
}

private struct AlarmRow: View {
    @Environment(AlarmStore.self) private var store
    let alarm: AlarmItem

    var body: some View {
        Toggle(isOn: Binding(get: { alarm.enabled }, set: { on in
            var alarm = alarm
            alarm.enabled = on
            store.save(alarm)
        })) {
            VStack(alignment: .leading) {
                Text(Calendar.current.date(from: DateComponents(hour: alarm.hour, minute: alarm.minute))!, style: .time)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                Text("\(alarm.title), \(alarm.daysSummary)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(alarm.enabled ? .primary : .secondary)
    }
}
