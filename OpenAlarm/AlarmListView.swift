import SwiftUI

struct AlarmListView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var editing: AlarmItem?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                if store.authorization == .denied {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Alarms won't ring", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                        Text("OpenAlarm isn't allowed to schedule alarms. Turn on Alarms in Settings.")
                            .foregroundStyle(Color.ink2)
                        Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                            .bold()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                TimelineView(.everyMinute) { context in
                    NextLine(next: store.nextRing(after: context.date), now: context.date)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                ForEach(store.sortedAlarms) { alarm in
                    AlarmRow(alarm: alarm) { editing = alarm }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.ink.opacity(0.16))
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.delete(alarm.id) }
                                .tint(Color.deleteRed)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.lcd)
            .overlay {
                if store.alarms.isEmpty {
                    VStack(spacing: 16) {
                        SegmentText(text: "  :  ").frame(height: 64)
                        Text("No Alarms").font(.title2.bold())
                        Text("Tap + to add one.").foregroundStyle(Color.ink2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(OutlineButtonStyle())
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem {
                    Button("Add Alarm", systemImage: "plus") { editing = AlarmItem() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(InkButtonStyle())
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $editing) { alarm in
                AlarmEditor(alarm: alarm, isNew: store.alarm(alarm.id) == nil)
            }
        }
    }
}

/// "Next Mon 06:30 · in 7 hr, 16 min": the one message above the list.
private struct NextLine: View {
    let next: (alarm: AlarmItem, date: Date)?
    let now: Date

    var body: some View {
        Group {
            if let next {
                let left = Duration.seconds(max(60, next.date.timeIntervalSince(now)))
                Text("Next \(Text(next.date, format: .dateTime.weekday(.abbreviated).hour().minute()).bold().foregroundStyle(Color.ink)) · in \(left.formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated)))")
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.ink2)
    }
}

private struct AlarmRow: View {
    @Environment(AlarmStore.self) private var store
    @ScaledMetric(relativeTo: .largeTitle) private var digitHeight = 50
    let alarm: AlarmItem
    let edit: () -> Void

    var body: some View {
        // The switch sits over the edit button so each keeps its own tap target.
        ZStack(alignment: .topTrailing) {
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 10) {
                    SegmentClock(hour: alarm.hour, minute: alarm.minute)
                        .frame(height: digitHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 12) {
                        Text(alarm.title).font(.headline).lineLimit(1)
                        Spacer()
                        if alarm.loud { Legend("Loud", boxed: true) }
                        if alarm.days.isEmpty {
                            Legend("Once")
                        } else {
                            DayStrip(days: alarm.days)
                        }
                    }
                }
                .opacity(alarm.enabled ? 1 : 0.35)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(Text(alarm.timeOfDay, style: .time)), \(alarm.title), \(alarm.daysSummary)\(alarm.loud ? ", Loud mode" : "")"))
            .accessibilityHint("Edit alarm")
            .accessibilityAddTraits(.isButton)

            Toggle(isOn: Binding(get: { alarm.enabled }, set: { on in
                var alarm = alarm
                alarm.enabled = on
                store.save(alarm)
            })) {}
            .fixedSize()
            .accessibilityLabel(Text("\(alarm.title), \(Text(alarm.timeOfDay, style: .time))"))
            .frame(height: digitHeight)
        }
        .padding(.vertical, 6)
    }
}

/// All seven weekdays in fixed positions, like printed LCD annunciators: active days inked, the rest faint.
private struct DayStrip: View {
    @ScaledMetric(relativeTo: .caption) private var cell = 15
    let days: Set<Int>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AlarmItem.orderedWeekdays, id: \.self) { day in
                Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                    .font(.caption.weight(.bold))
                    .frame(width: cell)
                    .opacity(days.contains(day) ? 1 : 0.2)
            }
        }
    }
}
