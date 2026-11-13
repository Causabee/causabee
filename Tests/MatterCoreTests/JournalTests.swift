import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The journal: what a matter opens on, its plan, and its days and folded months")
@MainActor
struct JournalTests {
    private func day(_ day: String) -> Date { MatterStatus.date(of: day) ?? .distantPast }

    private func matter() throws -> (ModelContext, Matter) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama")
        context.insert(matter)
        return (context, matter)
    }

    private func task(_ text: String, _ owner: Todo.Owner = .me, due: String? = nil, in matter: Matter, _ context: ModelContext) -> Todo {
        let todo = Todo(text: text, owner: owner, due: due, source: Source(kind: .conversation, pointer: "you", date: day("2026-09-01")), origin: text)
        context.insert(todo)
        todo.matter = matter
        return todo
    }

    private func date(_ what: String, _ on: String, time: String? = nil, in matter: Matter, _ context: ModelContext) {
        let visit = Appointment(what: what, day: on, time: time, place: nil, source: Source(kind: .mail, pointer: "x", date: day("2026-09-01")))
        context.insert(visit)
        visit.matter = matter
    }

    private func mail(_ subject: String, on: Date, id: String, in matter: Matter, _ context: ModelContext) -> Entry {
        let source = Source(kind: .mail, pointer: "imap://x;UID=\(id)", messageID: "<\(id)@x>", date: on)
        let entry = Entry(title: subject, from: "Nina Voss <nina@example.com>", date: on, source: source)
        entry.replyTo = ""
        context.insert(entry)
        entry.matter = matter
        return entry
    }

    @Test("A matter opens on its digest, where its next step is, however much is open; a closed one too")
    func opening() throws {
        let (context, matter) = try matter()
        for index in 0..<3 { _ = task("Task \(index)", in: matter, context) }
        date("Physio", "2026-10-01", in: matter, context)
        #expect(Journal.opening(matter, today: "2026-09-30") == .all)
        for index in 3..<9 { _ = task("Task \(index)", in: matter, context) }
        date("Visit", "2026-10-06", in: matter, context)
        #expect(Journal.opening(matter, today: "2026-09-30") == .all)
        matter.closedAt = day("2026-09-30")
        #expect(Journal.opening(matter, today: "2026-09-30") == .all)
    }

    @Test("Only the filters with something behind them show, and the open one always")
    func parts() throws {
        let (context, matter) = try matter()
        #expect(Journal.parts(of: matter, open: .all) == [.all])
        #expect(Journal.parts(of: matter, open: .notes) == [.all, .notes])
        _ = mail("Hello", on: day("2026-09-01"), id: "1", in: matter, context)
        _ = task("Call", in: matter, context)
        #expect(Journal.parts(of: matter, open: .all) == [.all, .plan, .mail])
    }

    @Test("The plan: tasks and dates stand on one day; late, undated and other people's tasks stand apart")
    func plan() throws {
        let (context, matter) = try matter()
        _ = task("Late", due: "2026-09-28", in: matter, context)
        _ = task("Thursday's task", due: "2026-10-01", in: matter, context)
        date("Physio", "2026-10-01", time: "11:00", in: matter, context)
        date("All day", "2026-10-01", in: matter, context)
        _ = task("Next week", due: "2026-10-05", in: matter, context)
        _ = task("Much later", due: "2026-11-20", in: matter, context)
        _ = task("Some day", in: matter, context)
        _ = task("Karl's", .other, due: "2026-10-03", in: matter, context)
        let first = task("First", due: "2026-10-02", in: matter, context)
        let after = task("After it", due: "2026-10-02", in: matter, context)
        after.waitsFor = first
        date("Past", "2026-09-01", in: matter, context)
        let done = task("Done", in: matter, context)
        done.isDone = true
        done.doneAt = day("2026-09-20")

        let plan = Journal.plan(MatterStatus(matter, today: day("2026-09-30")))
        #expect(plan.overdue.map(\.text) == ["Late"])
        #expect(plan.stretches.map(\.title) == ["This week", "Next week", "November"])
        let thursday = try #require(plan.stretches.first?.days.first)
        #expect(thursday.day == "2026-10-01")
        // The dates first, what the day is planned around, then the tasks.
        #expect(thursday.items.map(\.name) == ["All day", "Physio", "Thursday's task"])
        #expect(plan.noDay.map(\.text) == ["Some day"])
        #expect(plan.waiting.map(\.text) == ["Karl's"])
        #expect(plan.blocked.map(\.text) == ["After it"])
        #expect(plan.past.map(\.name) == ["Past"])
        #expect(plan.done.map(\.text) == ["Done"])
    }

    @Test("A week begins on Monday: Sunday still belongs to this week, the Monday after to the next")
    func weeks() {
        #expect(Journal.stretch(of: "2026-10-04", today: "2026-09-30") == "This week")
        #expect(Journal.stretch(of: "2026-10-05", today: "2026-09-30") == "Next week")
        #expect(Journal.stretch(of: "2026-10-11", today: "2026-09-30") == "Next week")
        #expect(Journal.stretch(of: "2026-10-12", today: "2026-09-30") == "October")
        #expect(Journal.stretch(of: "2027-01-12", today: "2026-09-30") == "January 2027")
        // On a Sunday the week is nearly over: the next day is next week's.
        #expect(Journal.stretch(of: "2026-10-05", today: "2026-10-04") == "Next week")
    }

    @Test("A day's tile says its weekday and its number, or its month where the day need not be this week's")
    func tile() {
        #expect(Journal.tile("2026-10-01").over == "THU")
        #expect(Journal.tile("2026-10-01").number == "1")
        #expect(Journal.tile("2026-10-01", month: true).over == "OCT")
    }

    @Test("Tasks in a card stand a day at a time, those without a day together")
    func days() {
        let days = Journal.Plan.days(of: ["a", "b", "c", "d"]) { ["a": "2026-10-01", "b": "2026-10-01", "c": "2026-10-02"][$0] }
        #expect(days.map(\.day) == ["2026-10-01", "2026-10-02", nil])
        #expect(days.map(\.things) == [["a", "b"], ["c"], ["d"]])
    }

    @Test("A short journal is read whole, a day at a time, the newest first")
    func short() throws {
        let (context, matter) = try matter()
        let today = day("2026-09-30").addingTimeInterval(9 * 3600)
        let entries = [mail("Today's", on: today, id: "1", in: matter, context),
                       mail("Yesterday's", on: today.addingTimeInterval(-86_400), id: "2", in: matter, context),
                       mail("Long ago", on: day("2026-03-02"), id: "3", in: matter, context)]
        let items = MailThreads.build(entries).map(RecordBrowse.Item.thread)
        let titles: [String] = Journal.lines(items: items, today: today).compactMap { if case .day(_, let title) = $0 { title } else { nil } }
        // The words are the app's own; the day inside them is written as the device writes it —
        // "SEP 30" in English, "30. SEP" where the region says so (F009 AC-3). So the test says
        // what the app writes around the day, and that the day itself is in there.
        #expect(titles.count == 3)
        #expect(titles[0].hasPrefix("TODAY · WED, ") && titles[0].contains("SEP") && titles[0].contains("30"))
        #expect(titles[1].hasPrefix("YESTERDAY · ") && titles[1].contains("SEP") && titles[1].contains("29"))
        #expect(titles[2].hasPrefix("MONDAY · ") && titles[2].contains("MAR") && titles[2].contains("2"))
    }

    @Test("A long journal folds what is older than a month into its months, each with what it held; opened, a month shows its days")
    func folds() throws {
        let (context, matter) = try matter()
        let today = day("2026-09-30").addingTimeInterval(9 * 3600)
        var entries: [Entry] = []
        for index in 0..<6 { entries.append(mail("Recent \(index)", on: today.addingTimeInterval(Double(index) * -86_400), id: "r\(index)", in: matter, context)) }
        for index in 0..<5 { entries.append(mail("July \(index)", on: day("2026-07-1\(index)"), id: "j\(index)", in: matter, context)) }
        let items = MailThreads.build(entries).map(RecordBrowse.Item.thread)

        let folded = Journal.lines(items: items, today: today)
        let folds: [Journal.Fold] = folded.compactMap { if case .fold(let fold) = $0 { fold } else { nil } }
        #expect(folds.map(\.title) == ["July"])
        #expect(folds.first?.count == "5 mails")
        #expect(folds.first?.about.contains("July") == true)
        #expect(folds.first?.isOpen == false)
        #expect(folded.filter { if case .item = $0 { true } else { false } }.count == 6)

        let open = Journal.lines(items: items, today: today, opened: ["2026-07"])
        #expect(open.filter { if case .item = $0 { true } else { false } }.count == 11)
        // A mail in an old month says which fold to open to go to it.
        let old = try #require(entries.last)
        #expect(Journal.fold(of: old.persistentModelID, items: items, today: today) == "2026-07")
        #expect(Journal.fold(of: try #require(entries.first).persistentModelID, items: items, today: today) == nil)
    }

    @Test("Notes, decisions and what was ticked off stand in the journal on their day")
    func others() throws {
        let (context, matter) = try matter()
        let today = day("2026-09-30").addingTimeInterval(9 * 3600)
        let note = MatterNote(text: "Spare key with Mrs. Adler")
        note.createdAt = today
        context.insert(note)
        note.matter = matter
        let decision = Decision(what: "Sunrise, not the others", why: "They start in October", decidedAt: today.addingTimeInterval(-3600))
        context.insert(decision)
        decision.matter = matter
        let done = task("Find the receipt", in: matter, context)
        done.isDone = true
        done.doneAt = today.addingTimeInterval(-7200)
        let lines = Journal.lines(items: [], notes: [note], decisions: [decision], done: [done], today: today)
        #expect(lines.count == 4)
        if case .day(_, let title) = lines[0] { #expect(title.hasPrefix("TODAY")) } else { Issue.record("The day stands first") }
        if case .note = lines[1] {} else { Issue.record("The newest stands on top") }
        if case .decision = lines[2] {} else { Issue.record("The decision comes second") }
        if case .done = lines[3] {} else { Issue.record("What was ticked off comes last") }
    }
}
