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

    @Test("Reminded the day before at nine: the owner's tasks and the deadlines still to come — not someone else's, not what is done")
    func reminders() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "kita", name: "Kita")
        context.insert(matter)
        func task(_ text: String, _ owner: Todo.Owner, due: String?, done: Bool = false) {
            let todo = Todo(text: text, owner: owner, due: due, source: Source(kind: .mail, pointer: text), origin: text)
            todo.isDone = done
            context.insert(todo)
            todo.matter = matter
        }
        task("Pay the fee", .me, due: "2026-11-10")
        task("Bring the form", .we, due: "2026-11-08")
        task("Teacher sends the list", .other, due: "2026-11-09")
        task("Already paid", .me, due: "2026-11-09", done: true)
        task("No day", .me, due: nil)
        task("Was yesterday", .me, due: "2026-11-05")
        let deadline = Deadline(what: "Registration closes", day: "2026-11-12", source: Source(kind: .mail, pointer: "d"))
        context.insert(deadline)
        deadline.matter = matter
        let now = MatterStatus.date(of: "2026-11-06")!.addingTimeInterval(12 * 3600)
        let reminders = Planning.reminders([matter], now: now)
        #expect(reminders.map(\.text) == ["Bring the form", "Pay the fee", "Registration closes"])
        #expect(reminders.map(\.isDeadline) == [false, false, true])
        let first = Calendar.current.dateComponents([.day, .hour], from: reminders[0].at)
        #expect(first.day == 7 && first.hour == 9)
        // The same thing planned again has the same id: it replaces itself.
        #expect(Planning.reminders([matter], now: now).map(\.id) == reminders.map(\.id))
    }

    @Test("Someone else's task says whom it waits for: a person it names, else whoever wrote its mail")
    func whom() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "care", name: "Care")
        context.insert(matter)
        for name in ["Medizinischer Dienst", "Petra Lindner"] {
            let party = Party(name: name)
            context.insert(party)
            let membership = Membership()
            membership.party = party
            membership.matter = matter
            context.insert(membership)
        }
        let mail = Entry(title: "Termin", from: "Petra Lindner <p.lindner@example.org>", date: nil,
                         source: Source(kind: .mail, pointer: "m", messageID: "<m1>"))
        mail.messageID = "<m1>"
        context.insert(mail)
        mail.matter = matter
        func task(_ text: String, owner: Todo.Owner = .other, messageID: String? = nil) -> Todo {
            let todo = Todo(text: text, owner: owner, due: nil, source: Source(kind: .mail, pointer: "x", messageID: messageID), origin: text)
            context.insert(todo)
            todo.matter = matter
            return todo
        }
        #expect(Journal.whom(task("Medizinischer Dienst sends a new date")) == "Medizinischer Dienst")
        #expect(Journal.whom(task("Send a new date", messageID: "<m1>")) == "Petra Lindner")
        #expect(Journal.whom(task("Send a new date")) == nil)
        // The owner's own says nothing of whom.
        #expect(Journal.whom(task("Medizinischer Dienst anrufen", owner: .me)) == nil)
    }
}
