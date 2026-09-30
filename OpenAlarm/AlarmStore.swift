import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import UserNotifications

struct OpenAlarmMetadata: AlarmMetadata {}

/// Owns the alarms, the ringing session and everything AlarmKit is told.
///
/// Per alarm, AlarmKit holds at most two alarms: the main one (id = `AlarmItem.id`, repeating or one-shot)
/// and a transient one (`transientID`, fixed date) for nag, snooze and the Loud-mode fallback.
@MainActor @Observable
final class AlarmStore {
    static let shared = AlarmStore()

    private(set) var alarms: [AlarmItem] = []
    private(set) var session: Session?
    private(set) var authorization = AlarmManager.shared.authorizationState

    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var loudTask: Task<Void, Never>?

    private struct Saved: Codable {
        var alarms: [AlarmItem]
        var session: Session?
    }
    private static let fileURL = URL.documentsDirectory.appending(path: "alarms.json")

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL) {
            do {
                let saved = try JSONDecoder().decode(Saved.self, from: data)
                alarms = saved.alarms
                session = saved.session
            } catch {
                print("load error: \(error)")
            }
        }
    }

    var sortedAlarms: [AlarmItem] {
        alarms.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    var ringing: AlarmItem? {
        guard let session, session.snoozedUntil == nil else { return nil }
        return alarm(session.alarmID)
    }

    var canSnooze: Bool {
        guard let session, let alarm = ringing else { return false }
        return alarm.maxSnoozes.map { session.snoozes < $0 } ?? true
    }

    func alarm(_ id: UUID) -> AlarmItem? {
        alarms.first { $0.id == id }
    }

    // MARK: Editing

    func save(_ alarm: AlarmItem) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        persist()
        Task { await sync() }
    }

    func delete(_ id: UUID) {
        guard let alarm = alarm(id) else { return }
        if session?.alarmID == id {
            Audio.shared.stop()
            session = nil
        }
        alarms.removeAll { $0.id == id }
        try? AlarmManager.shared.cancel(id: alarm.id)
        try? AlarmManager.shared.cancel(id: alarm.transientID)
        persist()
        Task { await sync() }
    }

    // MARK: Ringing

    func snooze() {
        guard var session, let alarm = ringing, canSnooze else { return }
        Audio.shared.stop()
        session.snoozes += 1
        let until = Date.now + Double(alarm.snoozeMinutes * 60)
        session.snoozedUntil = until
        self.session = session
        persist()
        Task {
            await scheduleTransient(alarm, at: until)
            restartLoud()
        }
    }

    /// Ends this occurrence. A one-shot alarm switches off; a repeating one stays scheduled.
    func stop() {
        guard let session, var alarm = alarm(session.alarmID) else { return }
        Audio.shared.stop()
        self.session = nil
        try? AlarmManager.shared.cancel(id: alarm.transientID)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [alarm.id.uuidString])
        alarm.finishOccurrence()
        save(alarm)
    }

    /// The system dismissed our alert: Stop slider, side or volume button, or swiping the app closed.
    /// The alarm isn't over, so it rings again in 2 s unless the app takes over first.
    func externalStop(_ id: UUID) async {
        guard let alarm = alarm(id) else { return }
        // Our own AlarmManager.stop in takeOver() can land here too; the app is already ringing then.
        if isActive && ringing?.id == id { return }
        markRinging(alarm)
        if Audio.shared.isRinging {
            // Loud mode keeps ringing by itself; AlarmKit is only the fallback.
            notify(alarm)
            await scheduleTransient(alarm, at: .now + 60)
        } else {
            await scheduleTransient(alarm, at: .now + 2)
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isActive = true
            authorization = AlarmManager.shared.authorizationState
            takeOver()
            if let alarm = ringing {
                try? AlarmManager.shared.cancel(id: alarm.transientID)
                if !Audio.shared.isRinging { play(alarm) }
            }
        case .background:
            isActive = false
            guard let alarm = ringing else { return }
            Task {
                if alarm.loud {
                    notify(alarm)
                    await scheduleTransient(alarm, at: .now + 60)
                } else {
                    Audio.shared.stop()
                    await scheduleTransient(alarm, at: .now + 2)
                }
            }
        default:
            break
        }
    }

    /// While the app is in front, AlarmKit only shows a banner, so the app stops it and rings itself.
    private func takeOver() {
        for alert in (try? AlarmManager.shared.alarms) ?? [] where alert.state == .alerting {
            guard let alarm = alarms.first(where: { $0.id == alert.id || $0.transientID == alert.id }) else { continue }
            try? AlarmManager.shared.stop(id: alert.id)
            markRinging(alarm)
            try? AlarmManager.shared.cancel(id: alarm.transientID)
            play(alarm)
        }
    }

    private func markRinging(_ alarm: AlarmItem) {
        let snoozes = session?.alarmID == alarm.id ? session!.snoozes : 0
        session = Session(alarmID: alarm.id, snoozes: snoozes)
        persist()
    }

    private func play(_ alarm: AlarmItem) {
        Audio.shared.ring(alarm.sound, volume: alarm.loud ? alarm.loudVolume : nil, fadeIn: alarm.fadeIn)
    }

    // MARK: AlarmKit

    func requestAuthorization() async {
        if AlarmManager.shared.authorizationState == .notDetermined {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
        authorization = AlarmManager.shared.authorizationState
        await sync()
    }

    func observe() async {
        for await _ in AlarmManager.shared.alarmUpdates where isActive {
            takeOver()
        }
    }

    /// Makes AlarmKit match `alarms`. The session's alarm is left alone; `stop()` hands it back here.
    func sync() async {
        let manager = AlarmManager.shared
        let known = Set(alarms.flatMap { [$0.id, $0.transientID] })
        for orphan in (try? manager.alarms) ?? [] where !known.contains(orphan.id) {
            try? manager.cancel(id: orphan.id)
        }
        for alarm in alarms where alarm.id != session?.alarmID {
            try? manager.cancel(id: alarm.id)
            try? manager.cancel(id: alarm.transientID)
            guard alarm.enabled else { continue }
            let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            let repeats: Alarm.Schedule.Relative.Recurrence = alarm.days.isEmpty ? .never : .weekly(alarm.days.sorted().map { weekdays[$0 - 1] })
            await schedule(alarm, id: alarm.id, .relative(.init(time: .init(hour: alarm.hour, minute: alarm.minute), repeats: repeats)))
        }
        restartLoud()
    }

    private func scheduleTransient(_ alarm: AlarmItem, at date: Date) async {
        try? AlarmManager.shared.cancel(id: alarm.transientID)
        await schedule(alarm, id: alarm.transientID, .fixed(date))
    }

    private func schedule(_ alarm: AlarmItem, id: UUID, _ schedule: Alarm.Schedule) async {
        let alert = AlarmPresentation.Alert(
            title: "\(alarm.title)",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        )
        let configuration = AlarmManager.AlarmConfiguration<OpenAlarmMetadata>.alarm(
            schedule: schedule,
            attributes: AlarmAttributes(presentation: AlarmPresentation(alert: alert), tintColor: .orange),
            stopIntent: StopIntent(alarmID: alarm.id.uuidString),
            sound: Sounds.url(alarm.sound) == nil ? .default : .named(alarm.sound)
        )
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        } catch {
            print("schedule error: \(error)")
        }
    }

    // MARK: Loud mode

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Quick way back into the app while Loud mode rings without a lock-screen alert.
    private func notify(_ alarm: AlarmItem) {
        let content = UNMutableNotificationContent()
        content.title = alarm.title
        content.body = "Alarm ringing. Open OpenAlarm to snooze or stop."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: nil))
    }

    private func restartLoud() {
        loudTask?.cancel()
        Audio.shared.setKeepalive(alarms.contains { $0.enabled && $0.loud })
        loudTask = Task { await loudLoop() }
    }

    // ponytail: one session at a time. A Loud alarm due while another alarm rings or snoozes falls back to plain AlarmKit.
    private func nextLoudEvent() -> (AlarmItem, Date)? {
        if let session {
            guard let until = session.snoozedUntil, let alarm = alarm(session.alarmID), alarm.loud else { return nil }
            return (alarm, until)
        }
        return alarms.filter { $0.enabled && $0.loud }
            .map { ($0, $0.nextFire(after: .now)) }
            .min { $0.1 < $1.1 }
    }

    private func loudLoop() async {
        while !Task.isCancelled {
            guard let (alarm, date) = nextLoudEvent() else { return }
            let wait = date.timeIntervalSinceNow - 5
            if wait > 0 {
                // Short naps so clock and time-zone changes are picked up.
                try? await Task.sleep(for: .seconds(min(wait, 60)))
                continue
            }
            // Push AlarmKit back a minute; it rings only if our own playback fails.
            if session == nil {
                try? AlarmManager.shared.cancel(id: alarm.id)
                session = Session(alarmID: alarm.id, snoozedUntil: date)
                persist()
            }
            await scheduleTransient(alarm, at: date + 60)
            try? await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow)))
            if Task.isCancelled { return }
            markRinging(alarm)
            play(alarm)
            if isActive {
                try? AlarmManager.shared.cancel(id: alarm.transientID)
            } else {
                notify(alarm)
            }
        }
    }

    private func persist() {
        do {
            try JSONEncoder().encode(Saved(alarms: alarms, session: session)).write(to: Self.fileURL, options: .atomic)
        } catch {
            print("save error: \(error)")
        }
    }
}

/// Runs when the system dismisses the alert (Stop slider, side or volume button, swiping the app closed) and opens the app.
struct StopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open ringing alarm"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            await AlarmStore.shared.externalStop(id)
        }
        return .result()
    }
}
