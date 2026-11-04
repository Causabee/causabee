import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Any item hidden, or moved to another matter")
@MainActor
struct HideAndMoveTests {
    func store() throws -> (ModelContext, Matter, Matter) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let care = Matter(key: "care", name: "Care for Mum")
        let flat = Matter(key: "flat", name: "Flat")
        context.insert(care)
        context.insert(flat)
        return (context, care, flat)
    }

    func task(_ text: String, in matter: Matter, _ context: ModelContext) -> Todo {
        let todo = Todo(text: text, owner: .me, due: nil, source: Source(kind: .conversation, pointer: ""), origin: "you#" + text)
        context.insert(todo)
        todo.matter = matter
        return todo
    }

    @Test("Hidden: off the plan, the people and the list to connect from, kept, and shown again")
    func hideAndShowAgain() throws {
        let (context, care, _) = try store()
        let todo = task("Order the bath seat", in: care, context)
        let note = MatterNote(text: "Ask about Thursdays")
        context.insert(note)
        note.matter = care
        let party = care.addContact(name: "Dr. Brandt", role: "GP", address: "", phone: "", in: context)!
        let photo = Document(name: "seat.jpg", contentType: "image/jpeg", byteCount: 1, source: Source(kind: .screenshot, pointer: "", messageID: "s:1"))
        context.insert(photo)
        photo.matter = care
        care.connect(.task(todo), .note(note), in: context)

        care.setHidden(.task(todo), true)
        care.setHidden(.person(party), true)
        #expect(care.openTodos.isEmpty && (care.todos ?? []).count == 1, "Off the plan, still kept")
        #expect(care.shownParties.isEmpty && care.parties.count == 1, "Off the people, still known to what reads mail")
        #expect(MatterStatus(care).memberships.isEmpty)
        #expect(!care.journalItems.contains(.task(todo)))
        #expect(care.connected(to: .note(note)).isEmpty, "Its chip goes from what it is connected to")
        #expect(Set(care.hiddenItems) == [.task(todo), .person(party)])

        care.setHidden(.task(todo), false)
        #expect(care.openTodos == [todo])
        #expect(care.connected(to: .note(note)).map(\.item) == [.task(todo)], "Shown again, with its connection")
        #expect(care.hiddenItems == [.person(party)])
    }

    @Test("Moved: it goes on its own, takes its links, and its connections stay behind and go")
    func moveATask() throws {
        let (context, care, flat) = try store()
        let todo = task("Measure the bathroom", in: care, context)
        let first = task("Ask the landlord", in: care, context)
        todo.waitsFor = first
        let link = WebLink(address: "https://example.org/seat")
        context.insert(link)
        link.matter = care
        link.todo = todo
        let note = MatterNote(text: "Door is 70 cm")
        context.insert(note)
        note.matter = care
        care.connect(.task(todo), .note(note), in: context)

        try care.move(.task(todo), to: flat, in: context)
        #expect(todo.matter === flat && link.matter === flat)
        #expect(todo.waitsFor == nil)
        #expect(care.openTodos == [first])
        #expect((care.connections ?? []).filter { !$0.isDeleted }.isEmpty)
        #expect(care.connected(to: .note(note)).isEmpty && flat.connected(to: .task(todo)).isEmpty)
    }

    @Test("A person moved is in the other matter instead, once; their other matters keep them")
    func moveAPerson() throws {
        let (context, care, flat) = try store()
        let party = care.addContact(name: "Petra Lindner", role: "Neighbour", address: "", phone: "", in: context)!
        try care.move(.person(party), to: flat, in: context)
        #expect(care.parties.isEmpty && flat.parties == [party])

        let again = flat.addContact(name: "Jonas Weber", role: "", address: "", phone: "", in: context)!
        care.addContact(name: "Jonas Weber", role: "", address: "", phone: "", in: context)
        try care.move(.person(again), to: flat, in: context)
        #expect(care.parties.isEmpty && flat.parties.filter { $0 === again }.count == 1)
    }
}
