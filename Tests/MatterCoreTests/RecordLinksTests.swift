import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Facts and the record are linked both ways")
@MainActor
struct RecordLinksTests {
    @Test("A mail knows the tasks and dates it brought and the task it showed done; a task finds its mail, a scan its file")
    func bothWays() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama")
        context.insert(matter)
        let first = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<a@x>", date: Date())
        let second = Source(kind: .mail, pointer: "imap://x;UID=2", messageID: "<b@x>", date: Date())
        let scan = Source(kind: .document, pointer: "/Users/r/Causabee/mama/Bescheid.pdf", messageID: "file-1", date: Date())
        for (title, source) in [("Pflegegrad", first), ("Re: Pflegegrad", second)] {
            let entry = Entry(title: title, from: "Kasse <k@x.example>", date: Date(), source: source)
            entry.matter = matter
            context.insert(entry)
        }
        let file = Document(name: "Bescheid.pdf", contentType: "application/pdf", byteCount: 10, source: scan)
        file.messageID = "file-1"
        file.matter = matter
        context.insert(file)
        let send = Todo(text: "Send the form", owner: .me, due: nil, source: first, origin: "a")
        send.sources.append(second.quoting("asked again"))
        let call = Todo(text: "Call the insurer", owner: .me, due: nil, source: first, origin: "b")
        call.isDone = true
        call.doneSource = second
        let visit = Appointment(what: "Assessment", day: "2026-10-06", time: "10:00", place: nil, source: first)
        let pay = Deadline(what: "Pay the fee", day: "2026-11-01", source: scan)
        for todo in [send, call] { todo.matter = matter; context.insert(todo) }
        visit.matter = matter; context.insert(visit)
        pay.matter = matter; context.insert(pay)
        let assistant = Todo(text: "Ask about the bed", owner: .me, due: nil, source: Source(kind: .conversation, pointer: "you"), origin: "c")
        assistant.matter = matter; context.insert(assistant)
        try context.save()

        let links = RecordLinks(matter)
        let entries = (matter.entries ?? []).sorted { $0.title < $1.title }
        #expect(links.made(from: entries[0]).todos.map(\.text) == ["Send the form", "Call the insurer"])
        #expect(links.made(from: entries[0]).appointments.count == 1)
        #expect(links.made(from: entries[1]).todos.map(\.text) == ["Send the form", "Call the insurer"])
        #expect(links.made(from: file).deadlines.map(\.what) == ["Pay the fee"])
        #expect(links.made(from: file).count == 1)

        #expect(RecordLinks.item(for: send.sources.first, in: matter) == entries[0].persistentModelID)
        #expect(RecordLinks.item(for: call.doneSource, in: matter) == entries[1].persistentModelID)
        #expect(RecordLinks.item(for: pay.sources.first, in: matter) == file.persistentModelID)
        #expect(RecordLinks.item(for: assistant.sources.first, in: matter) == nil)
    }
}
