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

    @Test("A question stopped before it goes out says its first step only, and sends nothing")
    func stoppedBeforeSending() async throws {
        let (_, matter) = try store()
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        let (steps, said) = AsyncStream.makeStream(of: AssistantAsk.Step.self)
        // Not started until this test waits for it: by then it is stopped.
        let asking = Task {
            defer { said.finish() }
            return try await AssistantAsk.ask(question: "Was ist offen?", inHand: nil, earlier: [], facts: facts, owner: nil,
                                              today: "2026-09-28", mapping: Pseudonymizer.Mapping(), others: [],
                                              claude: Claude(key: "no-key"), model: .opus) { said.yield($0) }
        }
        asking.cancel()
        let result = await asking.result
        #expect(throws: CancellationError.self) { try result.get() }
        var seen: [AssistantAsk.Step] = []
        for await step in steps { seen.append(step) }
        #expect(seen == [.disguising])
    }

    @Test("An answer copied is its lines and what the facts do not say, one under the other")
    func copied() throws {
        let reply = AssistantPrompt.Reply(lines: [.init(text: "Die Vollmacht ist offen.", cites: ["T1"]), .init(text: "Bis Freitag.", cites: [])],
                                          cards: [], notInFacts: "Ob er geantwortet hat, steht nicht da.")
        let answer = AssistantAsk.Answer(reply: reply, sent: "", cost: 0, seconds: 0, newNames: 0)
        #expect(answer.plainText == "Die Vollmacht ist offen.\nBis Freitag.\nOb er geantwortet hat, steht nicht da.")
        #expect(AssistantAsk.wasStopped(AssistantAsk.stopped))
        #expect(!AssistantAsk.wasStopped("http 529"))
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

    @Test("A screenshot taken in gives the assistant its kept words, not only its summary")
    func keptWords() throws {
        let (context, matter) = try store()
        let chat = Entry(title: "Chat: Beirat", from: "Beirat", date: Date(), source: Source(kind: .screenshot, pointer: "/x.png", messageID: "screenshot:ab"))
        chat.matter = matter
        context.insert(chat)
        try context.save()
        let words = "Bei mir ist kein Schreiben angekommen.\nWollen wir 11 Uhr telefonieren?"
        let facts = FactSheet.facts(for: [matter], today: "2026-10-01", keptText: { $0.messageID == "screenshot:ab" ? words : nil })
        #expect(facts.text.contains("its words: \"Bei mir ist kein Schreiben angekommen. / Wollen wir 11 Uhr telefonieren?\""))
        #expect(!FactSheet.facts(for: [matter], today: "2026-10-01").text.contains("its words"))
    }

    @Test("A person's share of the matter in words, and the one named most")
    func share() throws {
        let (context, matter) = try store()
        for index in 1...3 {
            let mail = Entry(title: "Mail \(index)", from: "x@example.com", date: Date(), source: Source(kind: .mail, pointer: "x\(index)", messageID: "m\(index)@example"))
            mail.matter = matter
            context.insert(mail)
        }
        func member(_ name: String, _ mentions: Int) -> Membership {
            let party = Party(name: name)
            context.insert(party)
            let membership = Membership()
            membership.party = party
            membership.matter = matter
            membership.mentions = mentions
            context.insert(membership)
            return membership
        }
        let most = member("Sebastian Süß", 4), some = member("Anna Keller", 2), none = member("Max Weber", 0)
        try context.save()
        #expect(most.share?.text == "in all 4 mails")
        #expect(most.share?.isMost == true)
        #expect(some.share?.text == "in 2 of 4 mails")
        #expect(some.share?.isMost == false)
        #expect(none.share == nil)
        some.mentions = 4
        #expect(most.share?.isMost == false)  // a tie at the top: nobody is "the most"
    }

    @Test("With a file in hand, the mail it came with is shown, whatever its subject")
    func fileInHand() throws {
        let (context, matter) = try store()
        let mail = Entry(title: "Heizung", from: "Hausmeister <h@example.com>", date: Date(), source: Source(kind: .mail, pointer: "x", messageID: "b@example"))
        mail.matter = matter
        let file = Document(name: "Wartungsprotokoll-2026.pdf", contentType: "application/pdf", byteCount: 1000,
                            source: Source(kind: .mail, pointer: "x", messageID: "b@example"))
        file.messageID = "b@example"
        file.matter = matter
        context.insert(mail)
        context.insert(file)
        try context.save()
        let facts = FactSheet.facts(for: [matter], today: "2026-09-28", focus: "Wartungsprotokoll-2026.pdf")
        #expect(facts.text.contains("The file in hand: Wartungsprotokoll-2026.pdf — came with the mail of"))
        #expect(facts.text.contains("from Hausmeister: Heizung"))
        #expect(facts.text.contains("not scanned yet"))
        #expect(facts.text.contains("Mails, newest first:"))
        #expect(!FactSheet.facts(for: [matter], today: "2026-09-28", focus: "Sebastian Süß").text.contains("file in hand"))
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
