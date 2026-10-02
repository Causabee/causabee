import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The overview's week, and pinned matters")
@MainActor
struct WeekTests {
    let today = ISO8601DateFormatter().date(from: "2026-10-02T10:00:00Z")!
    let source = Source(kind: .mail, pointer: "imap://x", messageID: "a@example", date: nil)

    func matter(_ key: String, _ context: ModelContext) -> Matter {
        let matter = Matter(key: key)
        context.insert(matter)
        return matter
    }

    @Test("Seven days from today, as the store writes them")
    func sevenDays() {
        let days = Week.days(from: today)
        #expect(days.count == 7)
        #expect(days.first == "2026-10-02")
        #expect(days.last == "2026-10-08")
    }

    @Test("A day lists tasks, deadlines and appointments of open matters — appointments by time first; a closed matter's are not there")
    func thingsOnADay() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let care = matter("care", context), tax = matter("tax", context), old = matter("old", context)
        let todo = Todo(text: "Send the bank statement", owner: .me, due: "2026-10-06", source: source, origin: "t")
        context.insert(todo); todo.matter = tax
        let visit = Appointment(what: "The medical service visits", day: "2026-10-06", time: "10:00", place: nil, source: source)
        context.insert(visit); visit.matter = care
        let deadline = Deadline(what: "Return the form", day: "2026-10-06", source: source)
        context.insert(deadline); deadline.matter = care
        let gone = Appointment(what: "Closed one", day: "2026-10-06", time: "09:00", place: nil, source: source)
        context.insert(gone); gone.matter = old
        old.close(markingOpenDone: false)
        try context.save()

        let things = Week.things(on: "2026-10-06", in: [care, tax, old])
        #expect(things.map(\.what) == ["The medical service visits", "Return the form", "Send the bank statement"])
        #expect(things.last?.todo === todo)
        #expect(Week.things(on: "2026-10-05", in: [care, tax, old]).isEmpty)
        #expect(Week.next(after: "2026-10-04", in: [care, tax, old])?.day == "2026-10-06")
        #expect(Week.next(after: "2026-10-06", in: [care, tax, old]) == nil)
    }

    @Test("Pinned ones come in the order they were pinned; closing a matter takes its pin away")
    func pins() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let a = matter("a", context), b = matter("b", context), c = matter("c", context)
        b.pinnedAt = today
        a.pinnedAt = today.addingTimeInterval(60)
        #expect(Pins.pinned([a, b, c]) === [b, a])
        b.close(markingOpenDone: false)
        #expect(!b.isPinned)
        #expect(Pins.pinned([a, b, c]) === [a])
    }
}

/// Two lists of matters are the same matters, in the same order.
private func === (left: [Matter], right: [Matter]) -> Bool {
    left.count == right.count && zip(left, right).allSatisfy { $0 === $1 }
}
