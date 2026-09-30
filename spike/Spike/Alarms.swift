import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI

struct SpikeMetadata: AlarmMetadata {}

enum Alarms {
    static func requestAuthorization() async {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            Log.write("auth: \(state)")
        } catch {
            Log.write("auth error: \(error)")
        }
    }

    /// `sound` is a file name in the bundle or Library/Sounds; empty means the system default.
    @discardableResult
    static func schedule(at date: Date, sound: String) async -> UUID? {
        let id = UUID()
        // Spike 5: Stop opens the app instead of a separate Open button.
        let stopOpens = UserDefaults.standard.bool(forKey: "stopOpens")
        let alert = AlarmPresentation.Alert(
            title: "Spike alarm",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: stopOpens ? nil : AlarmButton(text: "Open", textColor: .white, systemImageName: "arrow.up.forward.app"),
            secondaryButtonBehavior: stopOpens ? nil : .custom
        )
        let attributes = AlarmAttributes<SpikeMetadata>(presentation: AlarmPresentation(alert: alert), tintColor: .orange)
        let configuration = AlarmManager.AlarmConfiguration<SpikeMetadata>.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            stopIntent: stopOpens ? StopAndOpenIntent(alarmID: id.uuidString) : StopIntent(alarmID: id.uuidString),
            secondaryIntent: stopOpens ? nil : OpenIntent(alarmID: id.uuidString),
            sound: sound.isEmpty ? .default : .named(sound)
        )
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            Log.write("scheduled \(id.short) at \(date.formatted(date: .omitted, time: .standard)), sound '\(sound)'")
            return id
        } catch {
            Log.write("schedule error: \(error)")
            return nil
        }
    }

    static func handleStop(_ alarmID: String) async {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        if UserDefaults.standard.bool(forKey: "nag") {
            Log.write("nag: re-scheduling in 30 s")
            await schedule(at: .now + 30, sound: UserDefaults.standard.string(forKey: "sound") ?? "")
        }
    }

    static func stopAlerting() {
        for alarm in current() where alarm.state == .alerting {
            do {
                try AlarmManager.shared.stop(id: alarm.id)
                Log.write("in-app stop \(alarm.id.short)")
            } catch {
                Log.write("in-app stop error: \(error)")
            }
        }
    }

    static func cancelAll() {
        for alarm in current() {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
        Log.write("cancelled all alarms")
    }

    static func current() -> [Alarm] {
        (try? AlarmManager.shared.alarms) ?? []
    }

    /// Logs every AlarmKit state change while the app is running.
    static func observe() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            let states = alarms.map { "\($0.id.short)=\($0.state)" }.joined(separator: ", ")
            Log.write("alarmUpdates: [\(states)]")
        }
    }
}

extension UUID {
    var short: String { String(uuidString.prefix(4)) }
}

/// Runs when the system Stop button is pressed. Spike 1: can we re-schedule from here?
struct StopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop spike alarm"
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        Log.write("StopIntent.perform \(alarmID.prefix(4))")
        await Alarms.handleStop(alarmID)
        return .result()
    }
}

/// Same as StopIntent, but also brings the app to the foreground.
struct StopAndOpenIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop spike alarm and open app"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        Log.write("StopAndOpenIntent.perform \(alarmID.prefix(4))")
        await Alarms.handleStop(alarmID)
        return .result()
    }
}

/// Runs when the "Open" button is pressed and brings the app to the foreground.
struct OpenIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open spike app"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        Log.write("OpenIntent.perform \(alarmID.prefix(4))")
        return .result()
    }
}
