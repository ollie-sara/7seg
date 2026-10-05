import Foundation
import Testing
@testable import OpenAlarm

struct SegmentsTests {
    @Test func twentyFourHourPadsWithZero() {
        let clock = Segments.clock(hour: 6, minute: 5, locale: Locale(identifier: "de_DE"))
        #expect(clock.digits == "06:05")
        #expect(clock.period == nil)
    }

    @Test func twelveHourPadsWithBlankAndAddsPeriod() {
        let us = Locale(identifier: "en_US")
        #expect(Segments.clock(hour: 6, minute: 30, locale: us) == (" 6:30", "AM"))
        #expect(Segments.clock(hour: 0, minute: 0, locale: us) == ("12:00", "AM"))
        #expect(Segments.clock(hour: 23, minute: 15, locale: us) == ("11:15", "PM"))
    }
}
