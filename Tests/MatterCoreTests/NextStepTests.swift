import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The next step, and what waits for what")
@MainActor
struct NextStepTests {
    let today = ISO8601DateFormatter().date(from: "2026-09-28T10:00:00Z")!

    func matter() throws -> (ModelContext, Matter) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "reise")
        context.insert(matter)
        return (context, matter)
    }

    @discardableResult
    func todo(_ text: String, _ owner: Todo.Owner, due: String? = nil, in matter: Matter, _ context: ModelContext) -> Todo {
        let source = Source(kind: .mail, pointer: "imap://x", messageID: "\(text)@example", date: today.addingTimeInterval(-86_400 * 20))
        let todo = Todo(text: text, owner: owner, due: due, source: source, origin: text)
        context.insert(todo)
        todo.matter = matter
        return todo
    }

    @Test("The proof waits for the answer: it goes last, is not overdue, and the step is to wait for the answer")
    func waitsForTheAnswer() throws {
        let (context, matter) = try matter()
        let proof = todo("Nachweis der Versicherung einreichen", .me, due: "2026-09-20", in: matter, context)
        let answer = todo("Antwort des Reisebüros abwarten", .other, due: "2026-09-30", in: matter, context)
        try context.save()
        let before = MatterStatus(matter, today: today)
        #expect(before.nextStep?.kind == .overdue)
        #expect(before.nextStep?.text == proof.text)

        #expect(proof.wait(for: answer))
        let status = MatterStatus(matter, today: today)
        #expect(proof.isBlocked)
        #expect(status.overdue.isEmpty)
        let step = try #require(status.nextStep)
        #expect(step.kind == .wait)
        #expect(step.text == answer.text)
        #expect(step.why.contains("Sep 30") && step.why.contains("Then this can go ahead: Nachweis"))

        answer.isDone = true
        answer.doneAt = today
        #expect(!proof.isBlocked && proof.isFreed)
        #expect(MatterStatus(matter, today: today).nextStep?.text == proof.text)
    }

    @Test("Asking again once what was awaited is late; my own open to-do before only waiting")
    func order() throws {
        let (context, matter) = try matter()
        let reply = todo("Rückmeldung der Versicherung", .other, due: "2026-09-25", in: matter, context)
        #expect(MatterStatus(matter, today: today).nextStep?.kind == .followUp)
        #expect(MatterStatus(matter, today: today).nextStep?.todo == reply.persistentModelID)
        let mine = todo("Formular ausfüllen", .me, due: "2026-10-05", in: matter, context)
        // Waiting that is late still comes before my own that is not: the answer is what I lack.
        #expect(MatterStatus(matter, today: today).nextStep?.kind == .followUp)
        reply.isDone = true
        #expect(MatterStatus(matter, today: today).nextStep?.todo == mine.persistentModelID)
        #expect(MatterStatus(matter, today: today).nextStep?.kind == .doIt)
    }

    @Test("An appointment in the next days comes before a to-do with no hurry")
    func soon() throws {
        let (context, matter) = try matter()
        todo("Unterlagen sortieren", .me, in: matter, context)
        let visit = Appointment(what: "Begehung", day: "2026-09-30", time: "10:00", place: nil,
                                source: Source(kind: .mail, pointer: "x", messageID: "v@example"))
        context.insert(visit)
        visit.matter = matter
        let step = try #require(MatterStatus(matter, today: today).nextStep)
        #expect(step.kind == .date && step.text == "Begehung" && step.why.contains("at 10:00"))
    }

    @Test("A to-do that is a message to write is known as one; the reason ends with one full stop")
    func message() throws {
        let (context, matter) = try matter()
        let chase = todo("Lieferung Dachrinne nachfassen", .me, due: "2026-09-30", in: matter, context)
        #expect(chase.isMessage)
        #expect(!todo("Antwort des Reisebüros abwarten", .other, in: matter, context).isMessage)
        #expect(!todo("Unterlagen sortieren", .me, in: matter, context).isMessage)
        let why = try #require(MatterStatus(matter, today: today).nextStep?.why)
        #expect(why.hasPrefix("Due on Sep 30") && !why.contains(".."))
    }

    @Test("No to-do waits for itself, nor round in a circle")
    func circle() throws {
        let (context, matter) = try matter()
        let a = todo("A", .me, in: matter, context), b = todo("B", .me, in: matter, context), c = todo("C", .me, in: matter, context)
        #expect(!a.wait(for: a))
        #expect(a.wait(for: b) && b.wait(for: c))
        #expect(!c.wait(for: a))
        #expect(c.waitsFor == nil)
        #expect(a.wait(for: nil) && a.waitsFor == nil)
    }

    @Test("The assistant sees what waits for what, by id")
    func facts() throws {
        let (context, matter) = try matter()
        let proof = todo("Nachweis einreichen", .me, in: matter, context)
        let answer = todo("Antwort abwarten", .other, due: "2026-09-30", in: matter, context)
        proof.wait(for: answer)
        try context.save()
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        let answerID = try #require(facts.refs.first { $0.value == .todo(answer.persistentModelID) }?.key)
        #expect(facts.text.contains("Nachweis einreichen — can only be done after \(answerID)"))
    }

    @Test("A day string is read back as that day, and a day that does not exist is nil")
    func dayStrings() throws {
        let date = try #require(MatterStatus.date(of: "2026-09-30"))
        #expect(MatterStatus.day(date) == "2026-09-30")
        #expect(MatterStatus.date(of: "2026-02-31") == nil)
        #expect(MatterStatus.date(of: "30.09.2026") == nil)
        #expect(MatterStatus.date(of: "") == nil)
    }
}
