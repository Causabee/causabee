import Foundation
import Testing
@testable import MatterCore

@Suite("Today's things as the day goes on")
struct DayGoesTests {
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: hour, minute: minute))!
    }

    @Test("An appointment is over when its end has passed — the end it says, or an hour after it begins; a task never")
    func over() {
        let matter = Matter(key: "care")
        let physio = DayThing(matter: matter, what: "Physio", time: "09:00", todo: nil)
        let review = DayThing(matter: matter, what: "Portfolio review, 12:00–13:30", time: "12:00", todo: nil)
        let task = DayThing(matter: matter, what: "Send the salary slip", time: nil, todo: nil)
        let all = [physio, review, task]
        let day = MatterStatus.day(at(8))

        func ahead(_ now: Date) -> [String] { Week.asTheDayGoes(all, on: day, now: now).ahead.map(\.what) }
        #expect(ahead(at(8)) == ["Physio", "Portfolio review, 12:00–13:30", "Send the salary slip"])
        // Still going on: it began at nine and has no end of its own — an hour.
        #expect(ahead(at(9, 59)) == ["Physio", "Portfolio review, 12:00–13:30", "Send the salary slip"])
        #expect(ahead(at(10)) == ["Portfolio review, 12:00–13:30", "Send the salary slip"])
        // Its own end counts: at one it is still on, at half past it is over.
        #expect(ahead(at(13)) == ["Portfolio review, 12:00–13:30", "Send the salary slip"])
        #expect(ahead(at(13, 30)) == ["Send the salary slip"])
        #expect(Week.asTheDayGoes(all, on: day, now: at(23)).over.map(\.what) == ["Physio", "Portfolio review, 12:00–13:30"])
        // Another day: everything is ahead, whatever the hour.
        #expect(Week.asTheDayGoes(all, on: "2026-10-10", now: at(23)).over.isEmpty)
    }
}
