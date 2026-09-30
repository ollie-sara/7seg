import SwiftUI

@main
struct SpikeApp: App {
    init() {
        Log.write("app launched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @AppStorage("nag") private var nag = false
    @AppStorage("stopOpens") private var stopOpens = false
    @AppStorage("sound") private var sound = "rise10.caf"
    @State private var delay = 60.0
    @State private var volume = 1.0
    @State private var morning = Date.now + 8 * 3600
    @State private var sounds: [String] = []
    @State private var importing = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Setup") {
                    Button("Request AlarmKit permission") { Task { await Alarms.requestAuthorization() } }
                    Picker("Sound", selection: $sound) {
                        Text("System default").tag("")
                        ForEach(sounds, id: \.self) { Text($0).tag($0) }
                    }
                    Button("Import sound…") { importing = true }
                    Stepper("Fire in \(Int(delay)) s", value: $delay, in: 10...600, step: 10)
                }
                Section("1 · Stop button") {
                    Toggle("Nag: re-fire 30 s after system Stop", isOn: $nag)
                    Toggle("Stop opens app (no Open button)", isOn: $stopOpens)
                    Button("Schedule AlarmKit alarm") { Task { await Alarms.schedule(at: .now + delay, sound: sound) } }
                }
                Section("2 · Loud mode") {
                    Slider(value: $volume, in: 0...1) { Text("Volume") }
                    Text("Volume \(Int(volume * 100))%")
                    Button("Arm loud alarm") { Loud.shared.arm(at: .now + delay, volume: Float(volume), sound: sound) }
                    DatePicker("Overnight time", selection: $morning, displayedComponents: .hourAndMinute)
                    Button("Arm loud alarm at overnight time") {
                        let fire = morning > .now ? morning : morning + 24 * 3600
                        Loud.shared.arm(at: fire, volume: Float(volume), sound: sound)
                    }
                    Button("Silence loud mode") { Loud.shared.silence() }
                }
                Section("3 · In-app control") {
                    Button("Stop alerting alarms") { Alarms.stopAlerting() }
                    Button("Re-fire in 10 s") { Task { await Alarms.schedule(at: .now + 10, sound: sound) } }
                    Button("Cancel all alarms", role: .destructive) { Alarms.cancelAll() }
                }
                Section("Log (newest first)") {
                    ShareLink(item: Log.url)
                    Button("Clear log", role: .destructive) { Log.clear() }
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Log.read())
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Alarm Spike")
        }
        .background(VolumeHack().frame(width: 1, height: 1))
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result {
                Sounds.importFile(url)
                sounds = Sounds.list()
            }
        }
        .task {
            Sounds.generate()
            sounds = Sounds.list()
            await Alarms.observe()
        }
        .onChange(of: scenePhase) { _, phase in
            Log.write("scenePhase: \(phase)")
        }
    }
}
