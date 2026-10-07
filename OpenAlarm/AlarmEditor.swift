import SwiftUI

struct AlarmEditor: View {
    /// iOS 27 can give alarms their own volume; before that they follow the ringer.
    private static var systemVolumeName: String {
        if #available(iOS 27, *) { "Alarms and Timers" } else { "Ringtone and Alerts" }
    }

    @Environment(AlarmStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var alarm: AlarmItem
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                TimeSetter(hour: $alarm.hour, minute: $alarm.minute)
                    .listRowBackground(Color.clear)
                    .listSectionSeparator(.hidden)
                    .listRowSeparator(.hidden)

                Section {
                    TextField("Label", text: $alarm.label, prompt: Text("Alarm"))
                    VStack(alignment: .leading) {
                        Text("Repeat")
                        HStack(spacing: 4) {
                            ForEach(AlarmItem.orderedWeekdays, id: \.self) { day in
                                let on = alarm.days.contains(day)
                                Button {
                                    if on { alarm.days.remove(day) } else { alarm.days.insert(day) }
                                } label: {
                                    Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(on ? Color.lcd : Color.ink)
                                        .background(on ? Color.ink : Color.ink.opacity(0.07), in: .rect(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                        Text(alarm.days.isEmpty ? "Rings once, then switches off." : alarm.daysSummary)
                            .font(.footnote)
                            .foregroundStyle(Color.ink2)
                    }
                    NavigationLink {
                        SoundPicker(selection: $alarm.sound)
                    } label: {
                        LabeledContent("Sound", value: Sounds.displayName(alarm.sound))
                    }
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden)

                Section {
                    Picker("Duration", selection: $alarm.snoozeMinutes) {
                        ForEach(1...30, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Picker("Max snoozes", selection: $alarm.maxSnoozes) {
                        ForEach(0...10, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        Text("Unlimited").tag(Int?.none)
                    }
                } header: {
                    Text("Snooze").foregroundStyle(Color.ink2)
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden)

                Section {
                    LabeledContent("Max volume") {
                        HStack(spacing: 12) {
                            LevelBar(value: $alarm.volume)
                                .accessibilityLabel("Max volume")
                            // Sized for "100%" so the bar keeps its width.
                            Text("100%").hidden().overlay(alignment: .trailing) {
                                Text("\(Int((alarm.volume * 100).rounded()))%")
                            }
                            .monospacedDigit()
                            .accessibilityHidden(true)
                        }
                    }
                    Picker("Fade in", selection: $alarm.fadeSeconds) {
                        Text("Off").tag(Int?.none)
                        ForEach(AlarmItem.fadeChoices, id: \.self) { seconds in
                            Text(seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min").tag(Int?.some(seconds))
                        }
                    }
                } header: {
                    Text("Volume").foregroundStyle(Color.ink2)
                } footer: {
                    Text("On the Lock Screen the alarm rings up to this share of the system alarm volume, which apps can't change. For the loudest alarm, turn \(Self.systemVolumeName) all the way up in Settings → Sounds & Haptics. Once you open the app, it rings at medium volume.")
                        .foregroundStyle(Color.ink2)
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden)

                if !isNew {
                    Button("Delete Alarm", role: .destructive) {
                        store.delete(alarm.id)
                        dismiss()
                    }
                    .foregroundStyle(Color.deleteRed)
                    .listRowBackground(Color.clear)
                    .listSectionSeparator(.hidden)
                }
            }
            .sheetForm()
            .toggleStyle(LCDToggleStyle())
            .navigationTitle(isNew ? "Add Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .buttonStyle(.plain)
                        .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        alarm.enabled = true
                        store.save(alarm)
                        dismiss()
                    }
                    .buttonStyle(InkButtonStyle())
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }
}

struct SoundPicker: View {
    @Environment(AlarmStore.self) private var store
    @Binding var selection: String
    @State private var imported = Sounds.imported
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        List {
            Section {
                ForEach(Sounds.bundled, id: \.self, content: row)
            } header: {
                Text("Built-in").foregroundStyle(Color.ink2)
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
            Section {
                ForEach(imported, id: \.self) { name in
                    row(name).swipeActions {
                        Button("Delete", role: .destructive) { delete(name) }
                            .tint(Color.deleteRed)
                    }
                }
                Button("Import from Files…", systemImage: "square.and.arrow.down") { importing = true }
            } header: {
                Text("Imported").foregroundStyle(Color.ink2)
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
        }
        .scrollContentBackground(.hidden)
        .background(Color.lcd)
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

    /// Other alarms may still use the sound: `sync()` reschedules them, and a missing file falls back to the default.
    private func delete(_ name: String) {
        Audio.shared.stop()
        Sounds.delete(name)
        imported = Sounds.imported
        if selection == name { selection = Sounds.defaultName }
        Task { await store.sync() }
    }

    private func row(_ name: String) -> some View {
        Button {
            selection = name
            Audio.shared.preview(name)
        } label: {
            HStack {
                Text(Sounds.displayName(name))
                Spacer()
                if name == selection { Image(systemName: "checkmark").fontWeight(.semibold) }
            }
        }
        .accessibilityAddTraits(name == selection ? .isSelected : [])
    }
}
