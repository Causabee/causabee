import Foundation
import Testing
@testable import MatterCore

@MainActor @Suite("Where an appointment goes in Calendar: its start, its end, whole days or not")
struct EventSpanTests {
    private func at(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: day, hour: hour, minute: minute))!
    }

    @Test("The end it was given comes first, on its own day")
    func givenEnd() throws {
        let span = try #require(Calendars.span(what: "Viewing", day: "2026-05-12", time: "10:00", endTime: "11:30"))
        #expect(span.start == at(12, 10) && span.end == at(12, 11, 30) && !span.allDay)
    }

    @Test("An end before the start with no day of its own is the next morning")
    func overnight() throws {
        let span = try #require(Calendars.span(what: "Night shift", day: "2026-05-12", time: "22:00", endTime: "01:00"))
        #expect(span.start == at(12, 22) && span.end == at(13, 1))
    }

    @Test("A flight landing the next day ends on that day")
    func nextDay() throws {
        let span = try #require(Calendars.span(what: "Flight to Lisbon", day: "2026-05-12", time: "23:10", endDay: "2026-05-13", endTime: "06:45"))
        #expect(span.end == at(13, 6, 45))
    }

    @Test("No end given: one from its words, otherwise an hour")
    func fallback() throws {
        #expect(try #require(Calendars.span(what: "Review, 12:00–13:30", day: "2026-05-12", time: "12:00")).end == at(12, 13, 30))
        #expect(try #require(Calendars.span(what: "Call with Anna", day: "2026-05-12", time: "09:00")).end == at(12, 10))
    }

    @Test("A stay over several days fills each of them; one day ends on its day")
    func wholeDays() throws {
        let stay = try #require(Calendars.span(what: "Hotel", day: "2026-05-12", time: nil, endDay: "2026-05-15"))
        #expect(stay.allDay && stay.start == at(12) && stay.end == at(15))
        let one = try #require(Calendars.span(what: "Open day", day: "2026-05-12", time: nil))
        #expect(one.allDay && one.start == at(12) && one.end == at(12))
    }

    @Test("A time that is no time of day is a whole day, not midnight; an end before the start is never kept")
    func guards() throws {
        let vague = try #require(Calendars.span(what: "Visit", day: "2026-05-12", time: "morning"))
        #expect(vague.allDay && vague.start == at(12))
        #expect(try #require(Calendars.span(what: "Visit", day: "2026-05-12", time: "9:30")).start == at(12, 9, 30))
        let backwards = try #require(Calendars.span(what: "Visit", day: "2026-05-12", time: "10:00", endDay: "2026-05-11", endTime: "09:00"))
        #expect(backwards.end == at(12, 11))
        #expect(Calendars.span(what: "Visit", day: "2026-02-31", time: "10:00") == nil)
    }

    @Test func anEndSaidOnlyInWordsIsKept() throws {
        let span = try #require(Calendars.span(what: "Causabee test session — ends at 11:45 am", day: "2026-10-30", time: "10:00"))
        #expect(Calendar.current.dateComponents([.hour, .minute], from: span.end) == DateComponents(hour: 11, minute: 45))
        let german = try #require(Calendars.span(what: "Workshop bis 14:30 Uhr", day: "2026-10-30", time: "09:00"))
        #expect(Calendar.current.component(.hour, from: german.end) == 14)
    }
}
