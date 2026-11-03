import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("What came into a matter twice")
@MainActor
struct TwinsTests {
    func store() throws -> (ModelContext, Matter) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "bayonne", name: "Bayonne Reise")
        context.insert(matter)
        return (context, matter)
    }

    func file(_ name: String, _ bytes: Int, kind: Source.Kind, id: String, in matter: Matter, _ context: ModelContext) -> Document {
        let document = Document(name: name, contentType: "application/pdf", byteCount: bytes, source: Source(kind: kind, pointer: "", messageID: id))
        context.insert(document)
        document.matter = matter
        return document
    }

    @Test("A file's day in front of its name, from the matter's folder, does not make it another file")
    func days() {
        #expect(Twins.bareName("2026-10-30 RA_IN394063.pdf") == "RA_IN394063.pdf")
        #expect(Twins.bareName("2026-10-21 2026-10-20 Screenshot 2026-10-20 at 19.57.49.jpg") == "Screenshot 2026-10-20 at 19.57.49.jpg")
        #expect(Twins.same(("2026-10-30 INV0001.pdf", 101_431), ("INV0001.pdf", 101_431)))
        #expect(!Twins.same(("INV0001.pdf", 101_431), ("INV0001.pdf", 101_432)))
        #expect(!Twins.same(("Rechnung.pdf", 0), ("Rechnung.pdf", 0)))
    }

    @Test("A file added by hand that a mail brought too is put away, not deleted; once only")
    func byHand() throws {
        let (context, matter) = try store()
        let mine = file("2026-10-30 INV0001.pdf", 101_431, kind: .document, id: "document:1", in: matter, context)
        _ = file("INV0001.pdf", 101_431, kind: .mail, id: "mail-1", in: matter, context)
        let other = file("Policy.pdf", 2_000, kind: .document, id: "document:2", in: matter, context)
        #expect(try Twins.putAwayHandAddedTwins(in: context) == 1)
        #expect(mine.isHidden && !other.isHidden)
        #expect(Twins.has("2026-10-30 INV0001.pdf", bytes: 101_431, in: matter))
    }

    @Test("A mail two devices sorted: one entry, one of each task, file and date; the older task stays, done if either was")
    func twoDevices() throws {
        let (context, matter) = try store()
        let source = Source(kind: .mail, pointer: "", messageID: "m1")
        for digest in ["Rentscape asks for the damage report.", "The damage report is wanted by Rentscape."] {
            let entry = Entry(title: "394063", from: "a@b.fr", date: nil, source: source)
            entry.digest = digest
            context.insert(entry)
            entry.matter = matter
        }
        let older = Todo(text: "Send the report", owner: .me, due: nil, source: source, origin: "m1#send report")
        older.createdAt = Date(timeIntervalSince1970: 100)
        let newer = Todo(text: "Send the report", owner: .me, due: nil, source: source, origin: "m1#send report")
        newer.createdAt = Date(timeIntervalSince1970: 200)
        newer.isDone = true
        for todo in [older, newer] { context.insert(todo); todo.matter = matter }
        let linked = Appointment(what: "Hearing", day: "2026-11-10", time: nil, place: nil, source: source)
        linked.calendarID = "cal-1"
        let plain = Appointment(what: "Hearing", day: "2026-11-10", time: nil, place: nil, source: source)
        for date in [plain, linked] { context.insert(date); date.matter = matter }
        // The same attachment twice, alike in every way: only the device that sorted it first takes one away.
        _ = file("RA.pdf", 5_000, kind: .mail, id: "m1", in: matter, context)
        _ = file("RA.pdf", 5_000, kind: .mail, id: "m1", in: matter, context)
        let first = SortedMail(messageID: "m1", device: "iphone")
        first.sortedAt = Date(timeIntervalSince1970: 100)
        first.data = Data([1])
        let second = SortedMail(messageID: "m1", device: "mac")
        second.sortedAt = Date(timeIntervalSince1970: 200)
        second.data = Data([1])
        context.insert(first); context.insert(second)
        try context.save()

        let onMac = try Twins.tidy(in: context, device: "mac")
        #expect(onMac == Twins.Tidied(mails: 1, todos: 1, files: 0, dates: 1))
        #expect(matter.entries?.map(\.digest) == ["Rentscape asks for the damage report."])
        #expect(matter.todos?.count == 1 && matter.todos?.first?.createdAt == Date(timeIntervalSince1970: 100) && matter.todos?.first?.isDone == true)
        #expect(matter.appointments?.first?.calendarID == "cal-1")
        #expect(matter.documents?.count == 2)

        #expect(try Twins.tidy(in: context, device: "iphone").files == 1)
        #expect(matter.documents?.count == 1)
        #expect(try Twins.tidy(in: context, device: "iphone") == Twins.Tidied())
    }
}
