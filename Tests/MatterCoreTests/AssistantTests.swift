import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The assistant: facts with ids, and nothing identifiable in what is sent")
@MainActor
struct AssistantTests {
    func store() throws -> (ModelContext, Matter) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "hausverwaltung")
        context.insert(matter)
        let source = Source(kind: .mail, pointer: "imap://x", messageID: "a@example", date: Date(timeIntervalSince1970: 1_790_000_000), quote: "bitte bis Freitag")
        let todo = Todo(text: "Herrn Süß die Vollmacht schicken", owner: .me, due: "2026-10-02", source: source, origin: "a#1")
        todo.matter = matter
        context.insert(todo)
        let entry = Entry(title: "Vollmacht", from: "Sebastian Süß <sruess@example.com>", date: source.date, source: source)
        entry.matter = matter
        context.insert(entry)
        try context.save()
        return (context, matter)
    }

    func mapping() throws -> URL {
        var mapping = Pseudonymizer.Mapping()
        mapping.placeholder = [
            .init(kind: .person, original: "Sebastian Süß", standIn: "[Person A]"),
            .init(kind: .person, original: "Süß", standIn: "[Person A]", partOf: "Sebastian Süß"),
            .init(kind: .email, original: "sruess@example.com", standIn: "[Email A]"),
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mapping-\(UUID()).json")
        try JSONEncoder().encode(mapping).write(to: url)
        return url
    }

    @Test("Every fact has an id the answer can cite, and the id leads back to it")
    func ids() throws {
        let (_, matter) = try store()
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        #expect(facts.text.contains("T1 [me] Herrn Süß die Vollmacht schicken (due 2026-10-02)"))
        #expect(facts.text.contains("E1 "))
        #expect(facts.refs["T1"] == .todo(matter.todos!.first!.persistentModelID))
        #expect(facts.seen == "1 mail, 1 open task")
    }

    @Test("A known name in any spelling, and a new name typed in the question, are disguised")
    func disguised() throws {
        let (_, matter) = try store()
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        let prepared = try AssistantAsk.prepare(question: "Hat Herr Suess geantwortet, und was sagt Frau Annegret Wiesenthal dazu?",
                                                inHand: nil, earlier: [], facts: facts, owner: nil, today: "2026-09-28",
                                                mapping: try mapping(), saves: false)
        for word in ["Süß", "Suess", "Sebastian", "sruess", "Annegret", "Wiesenthal"] {
            #expect(!prepared.sent.contains(word), "\(word) would be sent: \(prepared.sent)")
        }
        #expect(prepared.newNames > 0)
        #expect(prepared.leaks(prepared.pseudonymizer.entries).isEmpty)
        #expect(prepared.sent.contains("Vollmacht"))
    }

    @Test("The owner's notes on a matter are read by the assistant, and a name in them is disguised")
    func notes() throws {
        let (_, matter) = try store()
        matter.notes = "Am Telefon mit Frau Annegret Wiesenthal: Termin wird verschoben, Vertragsnummer 4711-0815 liegt vor."
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        #expect(facts.text.contains("The owner's notes on this matter:"))
        #expect(facts.text.contains("Termin wird verschoben"))
        let prepared = try AssistantAsk.prepare(question: "Was steht in meinen Notizen?", inHand: nil, earlier: [], facts: facts,
                                                owner: nil, today: "2026-09-28", mapping: try mapping(), saves: false)
        for word in ["Annegret", "Wiesenthal", "4711-0815"] {
            #expect(!prepared.sent.contains(word), "\(word) would be sent: \(prepared.sent)")
        }
        #expect(prepared.sent.contains("verschoben"))

        matter.notes = "   "
        #expect(!FactSheet.facts(for: [matter], today: "2026-09-28").text.contains("notes on this matter"))
    }

    @Test("A shared document's address in the owner's notes leaves as a stand-in, not as itself")
    func linkInNotes() throws {
        let (_, matter) = try store()
        matter.notes = "Liste: https://docs.google.com/document/d/1AbCdEfSECRET/edit"
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        let prepared = try AssistantAsk.prepare(question: "Wo ist die Liste?", inHand: nil, earlier: [], facts: facts,
                                                owner: nil, today: "2026-09-28", mapping: try mapping(), saves: false)
        #expect(!prepared.sent.contains("SECRET"))
        #expect(prepared.links.values.contains { $0.contains("1AbCdEfSECRET") })
    }

    @Test("A list of names that is there but cannot be read stops the question: nothing is sent")
    func unreadableMapping() throws {
        let (_, matter) = try store()
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        // A folder where the file should be: it exists, and cannot be read as a file.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mapping-\(UUID().uuidString).json")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: MappingUnreadable.self) {
            try AssistantAsk.prepare(question: "Was ist offen?", inHand: nil, earlier: [], facts: facts,
                                     owner: nil, today: "2026-09-28", mapping: folder, saves: false)
        }
    }

    @Test("With a person in hand, only the mail that mentions them is shown")
    func focused() throws {
        let (context, matter) = try store()
        let other = Entry(title: "Heizung", from: "Hausmeister <h@example.com>", date: Date(), source: Source(kind: .mail, pointer: "x", messageID: "b@example"))
        other.matter = matter
        context.insert(other)
        try context.save()
        let all = FactSheet.facts(for: [matter], today: "2026-09-28")
        let few = FactSheet.facts(for: [matter], today: "2026-09-28", focus: "Sebastian Süß")
        #expect(all.text.contains("Heizung") && all.text.contains("Vollmacht"))
        #expect(!few.text.contains("Heizung") && few.text.contains("Vollmacht"))
        #expect(few.text.contains("T1"))  // the open to-dos stay: a correction may be about one
    }

    @Test("A name typed a letter short is read as the one person it almost is", arguments: [
        ("Bereite die Mail für Geor vor", "Bereite die Mail für Georg vor", 1),
        ("Schreib Gerog", "Schreib Georg", 1),
        ("Was macht Georg?", "Was macht Georg?", 0),
        ("Bereite den Termin vor", "Bereite den Termin vor", 0),
    ])
    func nameHints(typed: String, read: String, corrections: Int) {
        let (text, readAs) = NameHints.correct(typed, knowing: ["Georg Haller v Altenburg", "Sabine Hartwig"])
        #expect(text == read)
        #expect(readAs.count == corrections)
    }

    @Test("Two names near the typo: nothing is guessed")
    func ambiguous() {
        #expect(NameHints.correct("Mail an Ann", knowing: ["Anna Weber", "Anne Koch"]).readAs.isEmpty)
    }

    @Test("The answer reads back in the schema's shape")
    func reply() throws {
        let json = #"{"lines":[{"text":"[Person A] wartet auf die Vollmacht.","cites":["T1"]}],"cards":[{"kind":"mark_done","todo":"T1","text":"Vollmacht","owner":"me","due":null,"reason":"E1","cites":["E1"]}],"not_in_facts":null}"#
        let reply = try JSONDecoder().decode(AssistantPrompt.Reply.self, from: Data(json.utf8))
        #expect(reply.lines.first?.cites == ["T1"])
        #expect(reply.cards.first?.kind == .markDone)
    }
}
