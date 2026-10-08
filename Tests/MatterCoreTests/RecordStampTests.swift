import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("A matter's record, as a word that changes when the record does")
@MainActor
struct RecordStampTests {
    @Test("Another for a task added, done or changed, a mail, a date, a note; the same for the step and summary written from it")
    func stamp() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "bad", name: "Bad")
        context.insert(matter)
        var seen = [matter.recordStamp]
        func changed(_ what: String) {
            let now = matter.recordStamp
            #expect(!seen.contains(now), "No change seen: \(what)")
            seen.append(now)
        }
        let todo = Todo(text: "Fliesen bestellen", owner: .me, due: nil, source: Source(kind: .conversation, pointer: ""), origin: "t1")
        context.insert(todo); todo.matter = matter
        changed("a task added")
        todo.isDone = true
        changed("a task done")
        todo.text = "Fliesen bestellen, matt"
        changed("a task reworded")
        let day = ISO8601DateFormatter().date(from: "2026-09-14T10:00:00Z")!
        let entry = Entry(title: "Angebot", from: "x", date: day, source: Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "a@x", date: day))
        entry.messageID = "a@x"
        context.insert(entry); entry.matter = matter
        changed("a mail taken in")
        let deadline = Deadline(what: "Angebot annehmen", day: "2026-09-20", source: Source(kind: .conversation, pointer: ""))
        context.insert(deadline); deadline.matter = matter
        changed("a deadline")
        deadline.day = "2026-09-22"
        changed("a deadline moved")

        // What is written from the record is not the record: writing it changes nothing.
        let before = matter.recordStamp
        matter.nextStep = "Fliesen abholen"; matter.nextStepAt = Date()
        matter.summary = "Das Bad wird im Oktober gemacht."; matter.summaryAt = Date()
        #expect(matter.recordStamp == before)
    }
}
