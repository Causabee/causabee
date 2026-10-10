import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Deleted by hand, and brought back")
@MainActor
struct DeleteByHandTests {
    private func source() -> Source { Source(kind: .mail, pointer: "imap://x/;UID=1") }

    @Test("A task comes back as it was: its words, its note, its matter, its link, what waited for it")
    func aTaskComesBack() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try Matter.make(named: "Lisbon", in: context)
        let todo = Todo(text: "Choose the Sintra day", owner: .we, due: "2026-10-16", source: source(), origin: "T7")
        todo.dueTime = "10:20"
        todo.note = "ask Marta"
        todo.reminderID = "R-1"
        todo.matter = matter
        context.insert(todo)
        let waiting = Todo(text: "Book the Sintra train", owner: .me, due: nil, source: source(), origin: "T8")
        waiting.matter = matter
        context.insert(waiting)
        waiting.waitsFor = todo
        let link = WebLink(address: "https://example.com/sintra", title: "Sintra")
        context.insert(link)
        link.matter = matter
        link.todo = todo
        try context.save()

        let undo = UndoManager()
        context.deleteByHand([todo], undo: undo, named: "Delete Task")

        #expect(try context.fetch(FetchDescriptor<Todo>()).count == 1)
        #expect(undo.canUndo)
        #expect(undo.undoActionName == "Delete Task")

        undo.undo()

        let back = try #require(try context.fetch(FetchDescriptor<Todo>()).first { $0.text == "Choose the Sintra day" })
        #expect(back.owner == .we)
        #expect(back.due == "2026-10-16")
        #expect(back.dueTime == "10:20")
        #expect(back.note == "ask Marta")
        #expect(back.origin == "T7")
        #expect(back.sources.count == 1)
        #expect(back.matter?.name == "Lisbon")
        #expect(back.links?.first?.address == "https://example.com/sintra")
        #expect(waiting.waitsFor === back)
        // Its reminder went with it: it comes back unconnected.
        #expect(back.reminderID == nil)
        #expect(!context.hasChanges)
    }

    @Test("A date, a note, a detail and a link come back to their matter")
    func theOthersComeBack() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try Matter.make(named: "Lisbon", in: context)
        let appointment = Appointment(what: "Oceanário", day: "2026-10-19", time: "14:00", place: "Lisbon", source: source())
        let deadline = Deadline(what: "Pay", day: "2026-10-14", source: source())
        let note = MatterNote(text: "Marta has the keys", createdAt: Date(timeIntervalSince1970: 1_000), fromAssistant: true)
        let detail = MatterDetail(label: "Booking", value: "LX-4471")
        let link = WebLink(address: "https://example.com/tickets", title: "Tickets")
        for model in [appointment, deadline, note, detail, link] as [any PersistentModel] { context.insert(model) }
        appointment.matter = matter; deadline.matter = matter; note.matter = matter; detail.matter = matter; link.matter = matter
        try context.save()

        let undo = UndoManager()
        context.deleteByHand([appointment, deadline, note, detail, link], undo: undo, named: "Delete")
        #expect(try context.fetch(FetchDescriptor<Appointment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WebLink>()).isEmpty)

        undo.undo()

        let a = try #require(try context.fetch(FetchDescriptor<Appointment>()).first)
        #expect(a.what == "Oceanário" && a.day == "2026-10-19" && a.time == "14:00" && a.place == "Lisbon" && a.matter?.name == "Lisbon")
        let d = try #require(try context.fetch(FetchDescriptor<Deadline>()).first)
        #expect(d.what == "Pay" && d.day == "2026-10-14" && d.matter?.name == "Lisbon")
        let n = try #require(try context.fetch(FetchDescriptor<MatterNote>()).first)
        #expect(n.text == "Marta has the keys" && n.fromAssistant && n.createdAt == Date(timeIntervalSince1970: 1_000) && n.matter?.name == "Lisbon")
        let i = try #require(try context.fetch(FetchDescriptor<MatterDetail>()).first)
        #expect(i.label == "Booking" && i.value == "LX-4471" && i.matter?.name == "Lisbon")
        let l = try #require(try context.fetch(FetchDescriptor<WebLink>()).first)
        #expect(l.address == "https://example.com/tickets" && l.title == "Tickets" && l.matter?.name == "Lisbon")
    }

    @Test("What a mail check wrote meanwhile is not taken back")
    func onlyTheDeleteIsUndone() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try Matter.make(named: "Lisbon", in: context)
        let note = MatterNote(text: "Marta has the keys")
        context.insert(note)
        note.matter = matter
        try context.save()

        let undo = UndoManager()
        context.deleteByHand([note], undo: undo, named: "Delete Note")
        // As a mail check would, after the delete: something new, written past the undo manager.
        let fromMail = Todo(text: "Check in online", owner: .me, due: nil, source: source(), origin: "mail")
        context.insert(fromMail)
        fromMail.matter = matter
        try context.save()

        undo.undo()

        #expect(try context.fetch(FetchDescriptor<MatterNote>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Todo>()).count == 1)
        #expect(!undo.canUndo)
    }

    @Test("A person taken out of a matter comes back with their role, and the rule that kept them away goes")
    func aPersonComesBack() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try Matter.make(named: "Lisbon", in: context)
        let party = Party(name: "Marta Reis")
        context.insert(party)
        let membership = Membership()
        context.insert(membership)
        membership.party = party
        membership.matter = matter
        membership.roles = ["host"]
        membership.mentions = 3
        try context.save()

        let undo = UndoManager()
        membership.removeByHand(in: context, origin: "hand", undo: undo)

        #expect((matter.memberships ?? []).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Rule>()).contains { $0.kind == .notInMatter && $0.subject == "Marta Reis" })
        #expect(try context.fetch(FetchDescriptor<Party>()).count == 1)
        #expect(undo.undoActionName == "Remove Person")

        undo.undo()

        let back = try #require((matter.memberships ?? []).first)
        #expect(back.party?.name == "Marta Reis")
        #expect(back.roles == ["host"])
        #expect(back.mentions == 3)
        #expect(try context.fetch(FetchDescriptor<Rule>()).isEmpty)
    }

    @Test("Redo deletes it again, and Undo brings it back once more")
    func redo() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try Matter.make(named: "Lisbon", in: context)
        let note = MatterNote(text: "Marta has the keys")
        context.insert(note)
        note.matter = matter
        try context.save()

        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping(); context.deleteByHand([note], undo: undo, named: "Delete Note"); undo.endUndoGrouping()
        undo.undo()
        #expect(try context.fetch(FetchDescriptor<MatterNote>()).count == 1)
        #expect(undo.canRedo)
        #expect(undo.redoActionName == "Delete Note")
        undo.redo()
        #expect(try context.fetch(FetchDescriptor<MatterNote>()).isEmpty)
        #expect(undo.canUndo)
        undo.undo()
        #expect(try context.fetch(FetchDescriptor<MatterNote>()).first?.text == "Marta has the keys")
    }

    @Test("Without an undo manager it is simply deleted")
    func withoutUndo() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let detail = MatterDetail(label: "Booking", value: "LX-4471")
        context.insert(detail)
        try context.save()
        context.deleteByHand([detail], undo: nil, named: "Delete Detail")
        #expect(try context.fetch(FetchDescriptor<MatterDetail>()).isEmpty)
    }
}
