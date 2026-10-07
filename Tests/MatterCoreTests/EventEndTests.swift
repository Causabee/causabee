import Foundation
import Testing
@testable import MatterCore

@MainActor @Suite("When an event ends, read from the appointment's own words")
struct EventEndTests {
    private func at(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: hour, minute: minute))!
    }

    @Test("A range in 24 hours, a range with PM, one with no half of the day said, and words")
    func ranges() {
        #expect(Calendars.end(in: "Proposed portfolio review, 12:00–13:30", from: at(12, 0)) == at(13, 30))
        #expect(Calendars.end(in: "Interview availability, 3:30–6:00 PM (not confirmed)", from: at(15, 30)) == at(18, 0))
        #expect(Calendars.end(in: "Viewing 3:30-6:00", from: at(15, 30)) == at(18, 0))
        #expect(Calendars.end(in: "Workshop 9:00 AM to 12:30 PM", from: at(9, 0)) == at(12, 30))
        #expect(Calendars.end(in: "Termin 14.00 bis 15.15 Uhr", from: at(14, 0)) == at(15, 15))
    }

    @Test("No range, or an end that is not after the beginning: none")
    func none() {
        #expect(Calendars.end(in: "Dentist at 10:00", from: at(10, 0)) == nil)
        #expect(Calendars.end(in: "Call 16:00–15:00", from: at(16, 0)) == nil)
        #expect(Calendars.end(in: "Flight LH 1166", from: at(8, 0)) == nil)
    }
}
