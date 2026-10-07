import Foundation
import Testing
@testable import OpenAlarm

struct AlarmItemTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    /// Wednesday 2026-09-30 at the given time, Berlin.
    func wednesday(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour, minute: minute))!
    }

    @Test func oneShotLaterToday() {
        let alarm = AlarmItem(hour: 7, minute: 30)
        #expect(alarm.nextFire(after: wednesday(6, 0), calendar: calendar) == wednesday(7, 30))
    }

    @Test func oneShotAlreadyPassedMovesToTomorrow() {
        let alarm = AlarmItem(hour: 7, minute: 30)
        #expect(alarm.nextFire(after: wednesday(7, 30), calendar: calendar) == wednesday(7, 30) + 86_400)
    }

    @Test func repeatingPicksNearestDay() {
        // Monday (2) and Friday (6), asked on Wednesday: Friday.
        let alarm = AlarmItem(hour: 7, minute: 0, days: [2, 6])
        #expect(alarm.nextFire(after: wednesday(12, 0), calendar: calendar) == wednesday(7, 0) + 2 * 86_400)
    }

    @Test func repeatingTodayBeforeTime() {
        let alarm = AlarmItem(hour: 9, minute: 0, days: [4])
        #expect(alarm.nextFire(after: wednesday(8, 59), calendar: calendar) == wednesday(9, 0))
    }

    @Test func repeatingTodayAfterTimeWrapsAWeek() {
        let alarm = AlarmItem(hour: 9, minute: 0, days: [4])
        #expect(alarm.nextFire(after: wednesday(9, 1), calendar: calendar) == wednesday(9, 0) + 7 * 86_400)
    }

    @Test func acrossDSTChange() {
        // Berlin leaves DST on Sunday 2026-10-25 at 03:00; a Sunday 07:00 alarm still fires at 07:00 local.
        let alarm = AlarmItem(hour: 7, minute: 0, days: [1])
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 12))!
        let fire = alarm.nextFire(after: saturday, calendar: calendar)
        #expect(calendar.dateComponents([.day, .hour, .minute], from: fire) == DateComponents(day: 25, hour: 7, minute: 0))
        #expect(fire.timeIntervalSince(saturday) == 20 * 3600)
    }

    @Test func oneShotSwitchesOffAfterStop() {
        var alarm = AlarmItem()
        alarm.finishOccurrence()
        #expect(!alarm.enabled)
    }

    @Test func repeatingStaysOnAfterStop() {
        var alarm = AlarmItem(days: [2, 3])
        alarm.finishOccurrence()
        #expect(alarm.enabled)
    }

    @Test func nagIDsDifferAndAreStable() {
        let alarm = AlarmItem()
        #expect(alarm.transientID != alarm.id)
        #expect(alarm.transientID == alarm.transientID)
        #expect(Set([alarm.id, alarm.transientID, alarm.backupID]).count == 3)
    }

    @Test func decodesAlarmsSavedWithLoudMode() throws {
        var saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AlarmItem())) as! [String: Any]
        saved["fadeSeconds"] = nil
        saved["loud"] = true
        saved["loudVolume"] = 0.4
        saved["fadeIn"] = true
        let alarm = try JSONDecoder().decode(AlarmItem.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(alarm.volume == 0.4)
        #expect(alarm.fadeSeconds == nil)
    }
}
