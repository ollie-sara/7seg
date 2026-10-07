import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI

struct SevenSegMetadata: AlarmMetadata {}

/// Owns the alarms, the ringing session and everything AlarmKit is told.
///
/// Per alarm, AlarmKit holds at most three alarms: the main one (id = `AlarmItem.id`, repeating or one-shot)
/// a transient one (`transientID`, fixed date) for nag and snooze, and a backup nag (`backupID`).
/// AlarmKit plays a rendered copy of the sound with the alarm's volume and fade-in baked in (`Sounds.rendered`).
@MainActor @Observable
final class AlarmStore {
    static let shared = AlarmStore()

    private(set) var alarms: [AlarmItem] = []
    private(set) var session: Session?
    private(set) var authorization = AlarmManager.shared.authorizationState

    @ObservationIgnored private var isActive = false

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

    /// The next time anything rings: the earliest enabled alarm or the snoozed session.
    func nextRing(after date: Date = .now) -> (alarm: AlarmItem, date: Date)? {
        var candidates = alarms.filter(\.enabled).map { ($0, $0.nextFire(after: date)) }
        if let session, let until = session.snoozedUntil, let alarm = alarm(session.alarmID) {
            candidates.append((alarm, until))
        }
        return candidates.min { $0.1 < $1.1 }
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
        cancelNags(alarm)
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
        try? AlarmManager.shared.cancel(id: alarm.backupID)
        Task { await scheduleTransient(alarm, at: until, fade: true) }
    }

    /// Ends this occurrence. A one-shot alarm switches off; a repeating one stays scheduled.
    func stop() {
        guard let session, var alarm = alarm(session.alarmID) else { return }
        Audio.shared.stop()
        self.session = nil
        cancelNags(alarm)
        alarm.finishOccurrence()
        save(alarm)
    }

    /// The system dismissed our alert: Stop slider, side or volume button, or swiping the app closed.
    /// The alarm isn't over, so it rings again in 2 s unless the app takes over first.
    func externalStop(_ id: UUID) async {
        diag("externalStop active=\(isActive) ringing=\(ringing?.title ?? "-") alerts=\(((try? AlarmManager.shared.alarms) ?? []).map { "\($0.id == $0.id ? "" : "")\($0.state)" })") // DIAG
        guard let alarm = alarm(id) else { return }
        // Our own AlarmManager.stop in takeOver() can land here too; the app is already ringing then.
        if isActive && ringing?.id == id { return }
        markRinging(alarm)
        await nag(alarm)
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        diag("scenePhase \(phase)") // DIAG
        switch phase {
        case .active:
            isActive = true
            authorization = AlarmManager.shared.authorizationState
            takeOver()
            if let alarm = ringing {
                cancelNags(alarm)
                if !Audio.shared.isRinging { play(alarm) }
            }
        case .background:
            isActive = false
            guard let alarm = ringing else { return }
            Audio.shared.stop()
            Task { await nag(alarm) }
        default:
            break
        }
    }

    /// While the app is in front, AlarmKit only shows a banner, so the app stops it and rings itself.
    private func takeOver() {
        for alert in (try? AlarmManager.shared.alarms) ?? [] where alert.state == .alerting {
            guard let alarm = alarms.first(where: { [$0.id, $0.transientID, $0.backupID].contains(alert.id) }) else { continue }
            try? AlarmManager.shared.stop(id: alert.id)
            markRinging(alarm)
            cancelNags(alarm)
            if !Audio.shared.isRinging { play(alarm) }
        }
    }

    /// Rings again in 2 s, loud at once. The backup 10 s out covers a dismissal that never reaches `StopIntent`
    /// (side button on the passcode pad); every dismissal that does reach it pushes both out again.
    private func nag(_ alarm: AlarmItem) async {
        await scheduleTransient(alarm, at: .now + 2, fade: false)
        try? AlarmManager.shared.cancel(id: alarm.backupID)
        await schedule(alarm, id: alarm.backupID, .fixed(.now + 10), fade: false)
    }

    private func cancelNags(_ alarm: AlarmItem) {
        try? AlarmManager.shared.cancel(id: alarm.transientID)
        try? AlarmManager.shared.cancel(id: alarm.backupID)
    }

    private func markRinging(_ alarm: AlarmItem) {
        let snoozes = session?.alarmID == alarm.id ? session!.snoozes : 0
        session = Session(alarmID: alarm.id, snoozes: snoozes)
        persist()
    }

    /// The app is open, so the user is awake enough: medium volume, or the alarm's max if that's lower.
    private func play(_ alarm: AlarmItem) {
        Audio.shared.ring(alarm.sound, volume: min(alarm.volume, 0.5))
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
        let known = Set(alarms.flatMap { [$0.id, $0.transientID, $0.backupID] })
        for orphan in (try? manager.alarms) ?? [] where !known.contains(orphan.id) {
            try? manager.cancel(id: orphan.id)
        }
        for alarm in alarms where alarm.id != session?.alarmID {
            try? manager.cancel(id: alarm.id)
            cancelNags(alarm)
            guard alarm.enabled else { continue }
            let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            let repeats: Alarm.Schedule.Relative.Recurrence = alarm.days.isEmpty ? .never : .weekly(alarm.days.sorted().map { weekdays[$0 - 1] })
            await schedule(alarm, id: alarm.id, .relative(.init(time: .init(hour: alarm.hour, minute: alarm.minute), repeats: repeats)), fade: true)
        }
        Sounds.pruneRendered(keeping: alarms)
    }

    private func scheduleTransient(_ alarm: AlarmItem, at date: Date, fade: Bool) async {
        try? AlarmManager.shared.cancel(id: alarm.transientID)
        await schedule(alarm, id: alarm.transientID, .fixed(date), fade: fade)
    }

    /// `fade`: use the alarm's fade-in. Off for the nag, which must be loud at once.
    private func schedule(_ alarm: AlarmItem, id: UUID, _ schedule: Alarm.Schedule, fade: Bool) async {
        let started = Date.now // DIAG
        let sound = await Task.detached { Sounds.rendered(alarm, fade: fade) }.value
        diag("schedule \(id == alarm.id ? "main" : id == alarm.backupID ? "backup" : "transient") fade=\(fade) render took \(Date.now.timeIntervalSince(started)) s") // DIAG
        let alert = AlarmPresentation.Alert(
            title: "\(alarm.title)",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        )
        let configuration = AlarmManager.AlarmConfiguration<SevenSegMetadata>.alarm(
            schedule: schedule,
            attributes: AlarmAttributes(presentation: AlarmPresentation(alert: alert), tintColor: .orange),
            stopIntent: StopIntent(alarmID: alarm.id.uuidString),
            sound: sound.map { .named($0) } ?? .default
        )
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        } catch {
            print("schedule error: \(error)")
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
///
/// Starts in the background so the nag is scheduled even on a locked phone, then asks to open the app.
/// With `openAppWhenRun`, the system waited for the passcode before running `perform`; a button press
/// that ended on the passcode pad never scheduled the nag.
struct StopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open ringing alarm"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    @MainActor
    func perform() async throws -> some IntentResult {
        let run = UUID().uuidString.prefix(4) // DIAG
        diag("StopIntent \(run) perform start") // DIAG
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await AlarmStore.shared.externalStop(id)
        diag("StopIntent \(run) nag scheduled, throwing needsToContinueInForeground") // DIAG
        // Thrown, not awaited: while one run waits on the passcode pad, iOS doesn't start the next one,
        // so dismissing the nag from the pad would schedule nothing.
        throw needsToContinueInForegroundError(alwaysConfirm: false)
    }
}

/// DIAG: temporary. Appends to Documents/diag.log so device runs can be pulled with devicectl.
func diag(_ message: String) {
    let line = "\(Date.now.formatted(.iso8601.time(includingFractionalSeconds: true))) [\(UIApplication.shared.applicationState.rawValue)] \(message)\n"
    let url = URL.documentsDirectory.appending(path: "diag.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    } else {
        try? Data(line.utf8).write(to: url)
    }
}
