import Foundation

/// One alarm as the user configured it. AlarmKit keeps the schedule; this keeps everything else, linked by `id`.
struct AlarmItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var hour = 7
    var minute = 0
    var label = ""
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday. Empty = one-shot.
    var days: Set<Int> = []
    var enabled = true
    var sound = Sounds.defaultName
    var snoozeMinutes = 5
    /// nil = unlimited.
    var maxSnoozes: Int? = 3
    var loud = false
    var loudVolume = 1.0
    var fadeIn = true

    var title: String { label.isEmpty ? "Alarm" : label }

    /// Next time this alarm rings strictly after `date`.
    func nextFire(after date: Date, calendar: Calendar = .current) -> Date {
        let weekdays: [Int?] = days.isEmpty ? [nil] : days.map { $0 }
        return weekdays.compactMap { weekday in
            calendar.nextDate(
                after: date,
                matching: DateComponents(hour: hour, minute: minute, weekday: weekday),
                matchingPolicy: .nextTime
            )
        }.min()!
    }

    /// Called when the user stops a ringing occurrence in the app. A one-shot alarm switches itself off.
    mutating func finishOccurrence() {
        if days.isEmpty { enabled = false }
    }

    /// Stable id for the second AlarmKit alarm (nag, snooze, Loud-mode fallback). Only one of those exists at a time.
    var transientID: UUID {
        var bytes = id.uuid
        bytes.15 ^= 0xFF
        return UUID(uuid: bytes)
    }

    var daysSummary: String {
        switch days {
        case []: "Once"
        case Set(1...7): "Every day"
        case Set(2...6): "Weekdays"
        case [1, 7]: "Weekends"
        default: Self.orderedWeekdays.filter(days.contains).map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: " ")
        }
    }

    /// Weekdays in the user's locale order (e.g. Monday first).
    static var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }
}

/// The alarm currently ringing or snoozed. Persisted so a relaunch returns to the ringing screen.
struct Session: Codable, Equatable {
    var alarmID: UUID
    var snoozes = 0
    /// nil = ringing now.
    var snoozedUntil: Date?
}
