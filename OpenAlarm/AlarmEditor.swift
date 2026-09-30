import SwiftUI

struct AlarmEditor: View {
    @Environment(AlarmStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var alarm: AlarmItem
    let isNew: Bool

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: alarm.hour, minute: alarm.minute))! },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                alarm.hour = parts.hour!
                alarm.minute = parts.minute!
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                Section {
                    TextField("Label", text: $alarm.label, prompt: Text("Alarm"))
                    VStack(alignment: .leading) {
                        Text("Repeat")
                        HStack {
                            ForEach(AlarmItem.orderedWeekdays, id: \.self) { day in
                                let on = alarm.days.contains(day)
                                Button(Calendar.current.veryShortWeekdaySymbols[day - 1]) {
                                    if on { alarm.days.remove(day) } else { alarm.days.insert(day) }
                                }
                                .buttonStyle(.bordered)
                                .tint(on ? .orange : .gray)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                        Text(alarm.days.isEmpty ? "Rings once, then switches off." : alarm.daysSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        SoundPicker(selection: $alarm.sound)
                    } label: {
                        LabeledContent("Sound", value: Sounds.displayName(alarm.sound))
                    }
                }

                Section("Snooze") {
                    Picker("Duration", selection: $alarm.snoozeMinutes) {
                        ForEach(1...30, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Picker("Max snoozes", selection: $alarm.maxSnoozes) {
                        ForEach(0...10, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        Text("Unlimited").tag(Int?.none)
                    }
                }

                Section {
                    Toggle("Loud mode", isOn: $alarm.loud)
                    if alarm.loud {
                        LabeledContent("Volume \(Int(alarm.loudVolume * 100))%") {
                            Slider(value: $alarm.loudVolume, in: 0.1...1)
                        }
                        Toggle("Fade in over 15 s", isOn: $alarm.fadeIn)
                    }
                } footer: {
                    Text("Rings at the volume set here, even when the ringer is quiet. Only works while OpenAlarm stays open in the background: keep the phone plugged in and don't swipe the app closed. Otherwise the alarm rings at ringer volume.")
                }

                if !isNew {
                    Button("Delete Alarm", role: .destructive) {
                        store.delete(alarm.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle(isNew ? "Add Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        alarm.enabled = true
                        store.save(alarm)
                        dismiss()
                    }
                }
            }
            .onChange(of: alarm.loud) { _, on in
                if on { store.requestNotifications() }
            }
        }
    }
}

struct SoundPicker: View {
    @Binding var selection: String
    @State private var imported = Sounds.imported
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        List {
            Section("Built-in") {
                ForEach(Sounds.bundled, id: \.self, content: row)
            }
            Section("Imported") {
                ForEach(imported, id: \.self, content: row)
                Button("Import from Files…", systemImage: "square.and.arrow.down") { importing = true }
            }
        }
        .navigationTitle("Sound")
        .onDisappear { Audio.shared.stop() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            do {
                selection = try Sounds.importFile(result.get())
                imported = Sounds.imported
                Audio.shared.preview(selection)
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("Import failed", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func row(_ name: String) -> some View {
        Button {
            selection = name
            Audio.shared.preview(name)
        } label: {
            HStack {
                Text(Sounds.displayName(name)).foregroundStyle(.primary)
                Spacer()
                if name == selection { Image(systemName: "checkmark").foregroundStyle(.orange) }
            }
        }
        .accessibilityAddTraits(name == selection ? .isSelected : [])
    }
}
