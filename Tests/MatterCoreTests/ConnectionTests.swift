import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Items of a matter connected")
@MainActor
struct ConnectionTests {
    func store() throws -> (ModelContext, Matter) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "care", name: "Care for Mum")
        context.insert(matter)
        return (context, matter)
    }

    func mail(_ id: String, in matter: Matter, _ context: ModelContext) -> Entry {
        let entry = Entry(title: "Prescription ready", from: "brandt@example.org", date: nil, source: Source(kind: .mail, pointer: "", messageID: id))
        context.insert(entry)
        entry.matter = matter
        return entry
    }

    func task(_ text: String, from id: String?, in matter: Matter, _ context: ModelContext) -> Todo {
        let source = Source(kind: id == nil ? .conversation : .mail, pointer: "", messageID: id)
        let todo = Todo(text: text, owner: .me, due: nil, source: source, origin: (id ?? "you") + "#" + text)
        context.insert(todo)
        todo.matter = matter
        return todo
    }

    func file(_ name: String, id: String, kind: Source.Kind, in matter: Matter, _ context: ModelContext) -> Document {
        let document = Document(name: name, contentType: "image/jpeg", byteCount: 10, source: Source(kind: kind, pointer: "", messageID: id))
        context.insert(document)
        document.matter = matter
        return document
    }

    @Test("A task made by hand and a photo added later: connected, shown on both ends, both stay")
    func photoToTask() throws {
        let (context, matter) = try store()
        let todo = task("Get the bath seat prescription", from: nil, in: matter, context)
        let photo = file("Old seat.jpg", id: "screenshot:1", kind: .screenshot, in: matter, context)
        #expect(matter.connected(to: .task(todo)).isEmpty)

        #expect(matter.connect(.task(todo), .file(photo), in: context) != nil)
        try context.save()
        #expect(matter.connected(to: .task(todo)) == [Connected(item: .file(photo), kind: .with)])
        #expect(matter.connected(to: .file(photo)) == [Connected(item: .task(todo), kind: .with)])
        #expect(matter.connect(.file(photo), .task(todo), in: context) == nil, "Not twice, from either end")

        matter.disconnect(.file(photo), .task(todo), in: context)
        try context.save()
        #expect(matter.connected(to: .task(todo)).isEmpty && matter.connected(to: .file(photo)).isEmpty)
        #expect(matter.todos?.count == 1 && matter.documents?.count == 1)
    }

    @Test("What a task came from is shown as Causabee's, and taken away it stays away until connected again")
    func cameFrom() throws {
        let (context, matter) = try store()
        let entry = mail("m1", in: matter, context)
        let attachment = file("Prescription.pdf", id: "m1", kind: .mail, in: matter, context)
        let todo = task("Collect the prescription", from: "m1", in: matter, context)
        #expect(matter.connected(to: .task(todo)) == [Connected(item: .mail(entry), kind: .cameFrom)])
        #expect(Set(matter.connected(to: .mail(entry)).map(\.item)) == [.file(attachment), .task(todo)])
        #expect(matter.connected(to: .file(attachment)) == [Connected(item: .mail(entry), kind: .cameFrom)], "An attachment is the mail's, not each task's")

        matter.disconnect(.task(todo), .mail(entry), in: context)
        try context.save()
        #expect(matter.connected(to: .task(todo)).isEmpty)
        #expect(matter.connected(to: .mail(entry)) == [Connected(item: .file(attachment), kind: .cameFrom)])

        #expect(matter.connect(.mail(entry), .task(todo), in: context) == nil, "Its own link comes back; nothing new is made")
        try context.save()
        #expect(matter.connected(to: .task(todo)) == [Connected(item: .mail(entry), kind: .cameFrom)])
    }

    @Test("A person and a detail; deleting one end leaves the other alone")
    func personAndDetail() throws {
        let (context, matter) = try store()
        let party = Party(name: "Dr. Anselm Brandt")
        context.insert(party)
        let membership = Membership()
        context.insert(membership)
        membership.party = party
        membership.matter = matter
        let detail = MatterDetail(label: "Practice number", value: "123")
        context.insert(detail)
        detail.matter = matter
        let note = MatterNote(text: "Call before noon")
        context.insert(note)
        note.matter = matter
        matter.connect(.person(party), .detail(detail), in: context)
        matter.connect(.note(note), .person(party), in: context)
        try context.save()
        #expect(Set(matter.connected(to: .person(party)).map(\.item)) == [.detail(detail), .note(note)])

        context.delete(note)
        try context.save()
        #expect(matter.connected(to: .person(party)).map(\.item) == [.detail(detail)])
    }
}
