import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// A task with a day is a plan: "When?" gives it one in a tap, someone else's comes back when its
/// answer is due, and the week says in one sentence whether anything slips.
@Suite("Planning")
@MainActor
struct PlanningTests {
    @Test("This week is Friday — today at the weekend — next week the Friday after, later four weeks on")
    func days() {
        // 2026-11-04 is a Wednesday.
        #expect(Planning.day(.thisWeek, today: "2026-11-04") == "2026-11-06")
        #expect(Planning.day(.nextWeek, today: "2026-11-04") == "2026-11-13")
        #expect(Planning.day(.later, today: "2026-11-04") == "2026-12-02")
        // A Friday, a Saturday, a Monday.
        #expect(Planning.day(.thisWeek, today: "2026-11-06") == "2026-11-06")
        #expect(Planning.day(.thisWeek, today: "2026-11-07") == "2026-11-07")
        #expect(Planning.day(.nextWeek, today: "2026-11-07") == "2026-11-13")
        #expect(Planning.day(.nextWeek, today: "2026-11-09") == "2026-11-20")
    }

    @Test("Someone else's comes back a week after it came, or on its own day; waiting a week more puts it off")
    func comesBack() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "car", name: "Car")
        context.insert(matter)
        let theirs = Todo(text: "Insurer sends the assessment", owner: .other, due: nil, source: Source(kind: .mail, pointer: "x"), origin: "a")
        theirs.createdAt = MatterStatus.date(of: "2026-10-28")!
        context.insert(theirs)
        theirs.matter = matter
        #expect(Planning.comesBack(theirs) == "2026-11-04")
        #expect(!Planning.isBack(theirs, today: "2026-11-03"))
        #expect(Planning.isBack(theirs, today: "2026-11-04"))

        let plan = Journal.plan(MatterStatus(matter, today: MatterStatus.date(of: "2026-11-05")!))
        #expect(plan.noAnswer.map(\.text) == ["Insurer sends the assessment"])
        #expect(plan.waiting.isEmpty)

        Planning.waitAWeek(theirs, today: "2026-11-05")
        #expect(theirs.due == "2026-11-12")
        #expect(!Planning.isBack(theirs, today: "2026-11-05"))
        // The owner's own task never comes back as unanswered.
        let mine = Todo(text: "Call the garage", owner: .me, due: nil, source: Source(kind: .mail, pointer: "y"), origin: "b")
        mine.createdAt = theirs.createdAt
        #expect(!Planning.isBack(mine, today: "2026-12-01"))
    }

    @Test("The week in one sentence: calm when nothing slips, warning when something does")
    func week() {
        #expect(Planning.week(things: 3, waiting: 2, overdue: 0, unanswered: 0).map(\.text)
                == ["This week: 3 things", "waiting on 2", "nothing slipping"])
        let late = Planning.week(things: 1, waiting: 0, overdue: 2, unanswered: 1)
        #expect(late.map(\.text) == ["This week: 1 thing", "2 overdue", "1 without an answer"])
        #expect(late.map(\.warns) == [false, true, true])
        #expect(Planning.week(things: 0, waiting: 0, overdue: 0, unanswered: 0).map(\.text) == ["Nothing this week", "nothing slipping"])
    }
}
