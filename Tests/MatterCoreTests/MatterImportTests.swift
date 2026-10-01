import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// A classified mail as the log has it, with only what the import reads.
private func mail(_ id: String, _ matter: String?, day: Int, todos: [[String: Any]] = [], done: [[String: Any]] = [],
                  appointments: [[String: Any]] = [], parties: [[String: Any]] = [], bulk: Bool = false) throws -> Judgement {
    let json: [String: Any] = [
        "email_id": id, "source": "imap://imap.gmail.com/matterbee;UIDVALIDITY=7/;UID=\(day)",
        "date": "2026-09-\(String(format: "%02d", day))T10:00:00Z", "subject": "Mail \(id)", "from": "x@example.com",
        "is_bulk": bulk, "matter": matter as Any? ?? NSNull(), "matter_confidence": 0.9, "matter_reason": "",
        "decided_by": bulk ? "rule" : "claude", "parties": parties, "todos": todos, "deadlines": [],
        "appointments": appointments, "done": done,
    ]
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
}

private func todo(_ text: String, id: String, sameAs: String? = nil, owner: String = "me") -> [String: Any] {
    ["text": text, "owner": owner, "due": NSNull(), "source_quote": "…", "id": id, "same_as": sameAs as Any? ?? NSNull()]
}

@Suite("From the log to matters")
@MainActor
struct MatterImportTests {
    func log() throws -> [Judgement] {
        [
            try mail("a", "hausverwaltung", day: 1, todos: [todo("Angebot schicken", id: "T1")],
                     appointments: [["what": "Begehung", "date": "2026-10-09", "time": "10:00", "place": NSNull(), "source_quote": "…"]],
                     parties: [["name": "Sebastian Süß", "role": "unklar", "is_new": true]]),
            try mail("b", "hausverwaltung", day: 2, todos: [todo("Angebot und Vertrag schicken", id: "T1", sameAs: "T1")],
                     appointments: [["what": "Termin vor Ort", "date": "2026-10-09", "time": "10:00", "place": "Honigtauer", "source_quote": "…"]],
                     parties: [["name": "Sebastian Süß", "role": "Beirat", "is_new": false]]),
            try mail("c", "hausverwaltung", day: 3, done: [["todo": "T1", "source_quote": "Angebot anbei"]]),
            try mail("d", "reisestornierungmutter", day: 4, todos: [todo("Erstattung prüfen", id: "T2")]),
            try mail("e", nil, day: 5, bulk: true),
        ]
    }

    @Test("One to-do however often it is asked for, closed when a mail shows it done")
    func importing() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let summary = try MatterImport.apply(try log(), to: context)

        #expect(summary.mattersNew == 2)
        #expect(summary.mails == 4)
        #expect(summary.notImported == 1)
        #expect(summary.todosNew == 2)
        #expect(summary.todosAgain == 1)
        #expect(summary.todosDone == 1)
        #expect(summary.appointments == 1)

        let house = try #require(try context.fetch(FetchDescriptor<Matter>()).first { $0.key == "hausverwaltung" })
        #expect(house.entries?.count == 3)
        let angebot = try #require(house.todos?.first)
        #expect(angebot.sources.count == 2)
        #expect(angebot.isDone)
        #expect(angebot.doneSource?.quote == "Angebot anbei")
        #expect(house.appointments?.first?.sources.count == 2)
        #expect(house.appointments?.first?.place == "Honigtauer")
        let party = try #require(house.parties.first)
        #expect(house.membership(of: party)?.role == "Beirat")
    }

    @Test("Importing the same log again adds nothing, and leaves a reopened to-do open")
    func twice() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply(try log(), to: context)
        let reopened = try #require(try context.fetch(FetchDescriptor<Todo>()).first { $0.isDone })
        reopened.isDone = false

        let again = try MatterImport.apply(try log(), to: context)
        #expect(again.mails == 0)
        #expect(again.mailsAlreadyThere == 4)
        #expect(again.todosNew == 0 && again.todosAgain == 0 && again.todosDone == 0)
        #expect(try context.fetch(FetchDescriptor<Todo>()).count == 2)
        #expect(!reopened.isDone)
    }

    @Test("Nur Info: not open, not overdue, not done — kept, and shown to the assistant as worth knowing")
    func infos() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply(try log(), to: context)
        let trip = try #require(try context.fetch(FetchDescriptor<Matter>()).first { $0.key == "reisestornierungmutter" })
        let todo = try #require(trip.openTodos.first)
        todo.isInfo = true
        #expect(trip.openTodos.isEmpty && trip.infos.count == 1 && MatterStatus(trip).done.isEmpty)
        let facts = FactSheet.facts(for: [trip], today: "2026-09-28")
        #expect(facts.text.contains("Worth knowing (not to-dos):") && facts.text.contains(todo.text))
        #expect(facts.text.contains("No open to-dos."))
    }

    @Test("A mail's attachments become the matter's files — also for mail imported before — once each")
    func files() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        var judgement = try mail("f1", "hausverwaltung", day: 3)
        _ = try MatterImport.apply([judgement], to: context)
        judgement.attachments = [.init(filename: "Angebot.pdf", contentType: "application/pdf", byteCount: 120_000),
                                 .init(filename: "image001.png", contentType: "image/png", byteCount: 4_000)]
        let summary = try MatterImport.apply([judgement], to: context)
        _ = try MatterImport.apply([judgement], to: context)
        let house = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        #expect(summary.documents == 2)
        #expect(house.documents?.count == 2)
        #expect(house.documents?.first { $0.name == "image001.png" }?.isSmallImage == true)
        #expect(house.documents?.first { $0.name == "Angebot.pdf" }?.isReadable == true)
    }

    @Test("A matter made from nothing but a name: readable, filed by its folded key, never a second one with the same key")
    func madeFromNothing() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let first = try Matter.make(named: "Umzug Mama", in: context)
        let second = try Matter.make(named: "Umzug Mama", in: context)
        #expect(first.name == "Umzug Mama" && first.key == "umzugmama")
        #expect(second.key == "umzugmama2")
        _ = try MatterImport.apply([try mail("u1", "umzugmama", day: 9)], to: context)
        #expect(first.entries?.count == 1)
    }

    @Test("A new matter is shown by the title the model wrote, and filed by its key")
    func title() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        var first = try mail("s1", "sperrmuell", day: 7)
        first.matterTitle = "Sperrmüll"
        _ = try MatterImport.apply([first, try mail("s2", "fahrrad", day: 8)], to: context)
        let matters = try context.fetch(FetchDescriptor<Matter>())
        #expect(matters.first { $0.key == "sperrmuell" }?.name == "Sperrmüll")
        #expect(matters.first { $0.key == "fahrrad" }?.name == "Fahrrad")
    }

    @Test("Closing ticks what is open only when asked; reopening opens exactly those again")
    func closing() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply(try log(), to: context)
        let trip = try #require(try context.fetch(FetchDescriptor<Matter>()).first { $0.key == "reisestornierungmutter" })
        let house = try #require(try context.fetch(FetchDescriptor<Matter>()).first { $0.key == "hausverwaltung" })
        #expect(trip.openTodos.count == 1)

        trip.close(markingOpenDone: false, at: Date(timeIntervalSince1970: 1_790_000_000))
        #expect(trip.isClosed && trip.openTodos.count == 1)
        trip.reopen()

        let doneBefore = (house.todos ?? []).filter(\.isDone).count
        house.close(markingOpenDone: true)
        #expect(house.openTodos.isEmpty)
        house.reopen()
        #expect(!house.isClosed)
        #expect((house.todos ?? []).filter(\.isDone).count == doneBefore)  // done before stays done

        trip.close(markingOpenDone: false, at: Date(timeIntervalSince1970: 1_789_000_000))
        _ = try MatterImport.apply([try mail("late", "reisestornierungmutter", day: 30)], to: context)
        #expect(trip.isClosed)
        #expect(MatterStatus(trip).mailsSinceClosed.count == 1)
    }

    @Test("A mail moved to another matter takes what only it brought; a task another mail said too stays")
    func moveMail() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let shine = try Matter.make(named: "Shine application", in: context)
        let superhuman = try Matter.make(named: "Superhuman application", in: context)
        func entry(_ id: String) -> (Entry, Source) {
            let source = Source(kind: .mail, pointer: "imap://x/\(id)", messageID: id, date: Date())
            let e = Entry(title: "Mail \(id)", from: "Robbie Kerr <robbie@superhuman.example>", date: Date(), source: source)
            e.matter = shine
            context.insert(e)
            return (e, source)
        }
        let (wrong, wrongSource) = entry("w@x"), (_, otherSource) = entry("o@x")
        let alone = Todo(text: "Prepare for the interview", owner: .me, due: nil, source: wrongSource, origin: "w@x#interview")
        let shared = Todo(text: "Send the portfolio", owner: .me, due: nil, source: wrongSource, origin: "w@x#portfolio")
        shared.sources.append(otherSource)
        for todo in [alone, shared] { todo.matter = shine; context.insert(todo) }
        let date = Appointment(what: "Interview", day: "2026-10-08", time: "17:30", place: nil, source: wrongSource)
        date.matter = shine
        context.insert(date)
        try context.save()

        try shine.move([wrong], into: superhuman, in: context)
        #expect(wrong.matter === superhuman)
        #expect(alone.matter === superhuman)
        #expect(date.matter === superhuman)
        #expect(shared.matter === shine)  // another mail said it too
        #expect((shine.entries ?? []).count == 1)
        try superhuman.move([wrong], into: superhuman, in: context)  // into itself: nothing happens
        #expect(wrong.matter === superhuman)
    }

    @Test("Merging keeps the owner's notes of both matters")
    func mergingKeepsNotes() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let a = try Matter.make(named: "Dach undicht", in: context)
        let b = try Matter.make(named: "Dachdecker", in: context)
        a.notes = "Angebot bis Freitag"
        b.notes = "Rückruf Montag"
        a.absorb(b, in: context)
        try context.save()
        #expect(a.notes?.contains("Angebot bis Freitag") == true)
        #expect(a.notes?.contains("Rückruf Montag") == true)
        #expect(a.notes?.contains("From “Dachdecker”") == true)

        let c = try Matter.make(named: "Dachrinne", in: context)
        let empty = try Matter.make(named: "Leer", in: context)
        c.notes = nil
        empty.notes = "Nur hier"
        c.absorb(empty, in: context)
        #expect(c.notes == "Nur hier")
    }

    @Test("A rule of a kind this version does not know is never read as another kind")
    func unknownRuleKind() {
        let rule = Rule(.sameParty, subject: "A", object: "B", matterKey: nil, origin: "test")
        rule.kindRaw = "somethingNewer"
        #expect(rule.kind == nil)
        #expect(rule.kind != .sameParty)
    }

    @Test("A merged matter keeps receiving its mail under its old name")
    func merging() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        var judgements = try log()
        judgements[3].matter = "reisestornierung"
        judgements.insert(try mail("d2", "reisestornierungmutter", day: 4, todos: [todo("Beleg senden", id: "T3")]), at: 4)
        _ = try MatterImport.apply(judgements, to: context)

        let matters = try context.fetch(FetchDescriptor<Matter>())
        let trip = try #require(matters.first { $0.key == "reisestornierung" })
        let mother = try #require(matters.first { $0.key == "reisestornierungmutter" })
        trip.absorb(mother, in: context)
        trip.rename(to: "Reisen stornieren")
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Matter>()).count == 2)
        #expect(trip.entries?.count == 2)
        #expect(trip.todos?.count == 2)
        #expect(trip.answers(to: "reisestornierungmutter"))

        let later = try MatterImport.apply([try mail("f", "reisestornierungmutter", day: 6)], to: context)
        #expect(later.mattersNew == 0)
        #expect(trip.entries?.count == 3)
        #expect(trip.name == "Reisen stornieren")
    }
}

@Suite("People: each once, never the owner, a role per matter")
@MainActor
struct PartyTests {
    static let owner = ["Jan Kramer", "jan@kramer.example"]

    func person(_ name: String, _ role: String) -> [String: Any] { ["name": name, "role": role, "is_new": true] }

    func log() throws -> [Judgement] {
        [
            try mail("h1", "hausverwaltung", day: 1, parties: [
                person("Frau Dr. Petra Lindner (Mimi)", "Beirätin"), person("Kramer", "Beirat"), person("Jan", "Verfasser"),
                person("Sebastian Süß", "Beiratsvorsitzender"),
            ]),
            try mail("h2", "hausverwaltung", day: 2, parties: [
                person("Petralindner", "unklar"), person("Doktor Petra Lindner", "Miteigentümerin"), person("Süss", "unklar"),
                person("suess", "Verwaltungsbeirat"), person("Frau Kurz (anna.kurz@firma.example)", "Vermittlerin"),
            ]),
            try mail("m1", "mutterdach", day: 3, parties: [
                person("Greta Kramer", "Mutter, Eigentümerin"), person("Kramer", "Mutter, Eigentümerin"), person("Sebastian Albers", "Gutachter"),
            ]),
        ]
    }

    func store() throws -> ModelContext {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply(try log(), to: context, owner: Self.owner)
        return context
    }

    func matter(_ key: String, _ context: ModelContext) throws -> Matter {
        try #require(try context.fetch(FetchDescriptor<Matter>()).first { $0.key == key })
    }

    @Test("One person written four ways is one party; the owner is none of them")
    func spellings() throws {
        let context = try store()
        let house = try matter("hausverwaltung", context)
        let names = Set(house.parties.map(\.name))
        #expect(names.contains("Petra Lindner"))
        #expect(!names.contains { $0.contains("Kramer") || $0 == "Jan" })
        let harz = try #require(house.parties.first { $0.name == "Petra Lindner" })
        #expect(harz.spellings.count == 3)
        #expect(house.membership(of: harz)?.role == "Miteigentümerin")
        #expect(names.contains("Kurz"))
        // Süß, Süss and suess are one spelling apart, and one party.
        #expect(house.parties.filter { PartyNames.key($0.name) == "suess" }.count == 1)
    }

    @Test("A bare Kramer is the owner in the house, and not in the mother's matter; roles stay in their matter")
    func barenames() throws {
        let context = try store()
        let roof = try matter("mutterdach", context)
        #expect(roof.parties.contains { $0.name == "Kramer" })
        #expect(roof.parties.contains { $0.name == "Greta Kramer" })
        let house = try matter("hausverwaltung", context)
        #expect(!house.parties.contains { $0.name.contains("Kramer") })
    }

    @Test("A likely match is suggested with a reason; yes makes a rule that holds for the next mail")
    func suggestAndRule() throws {
        let context = try store()
        let house = try matter("hausverwaltung", context)
        let suggestions = PartyBook.suggestions(in: house, rules: [])
        let suess = try #require(suggestions.first { PartyNames.key($0.party.name) == "suess" })
        #expect(suess.into.name == "Sebastian Süß")

        let rule = Rule(.sameParty, subject: suess.party.name, object: suess.into.name, matterKey: "hausverwaltung", origin: "test")
        context.insert(rule)
        PartyBook.merge(suess.party, into: suess.into, context: context)
        try context.save()
        #expect(house.parties.filter { PartyNames.tokens($0.name).contains("suess") }.count == 1)

        _ = try MatterImport.apply([try mail("h3", "hausverwaltung", day: 4, parties: [person("Süss", "Beirat")])], to: context, owner: Self.owner)
        #expect(rule.fired == 1)
        #expect(house.parties.filter { PartyNames.tokens($0.name).contains("suess") }.count == 1)

        rule.isOn = false
        _ = try MatterImport.apply([try mail("h4", "hausverwaltung", day: 5, parties: [person("Süss", "Beirat")])], to: context, owner: Self.owner)
        #expect(house.parties.filter { PartyNames.tokens($0.name).contains("suess") }.count == 2)
    }

    @Test("Two parties with the same name are suggested, and a merge keeps the own role")
    func sameNameAndRole() throws {
        let context = try store()
        let house = try matter("hausverwaltung", context)
        let suess = try #require(house.parties.first { PartyNames.key($0.name) == "suess" })
        suess.name = "Sebastian Süß"
        let suggestion = try #require(PartyBook.suggestions(in: house, rules: []).first { $0.reason == "the same name twice" })
        #expect(suggestion.into.name == "Sebastian Süß" && suggestion.party !== suggestion.into)
        let own = house.membership(of: suggestion.into)?.role
        PartyBook.merge(suggestion.party, into: suggestion.into, context: context)
        #expect(own != nil && house.membership(of: suggestion.into)?.role == own)
    }

    @Test("A no is kept: the pair is not suggested again")
    func notSame() throws {
        let context = try store()
        let roof = try matter("mutterdach", context)
        #expect(PartyBook.suggestions(in: roof, rules: []).contains { $0.party.name == "Kramer" && $0.into.name == "Greta Kramer" })
        let no = Rule(.notSameParty, subject: "Kramer", object: "Greta Kramer", matterKey: "mutterdach", origin: "test")
        #expect(!PartyBook.suggestions(in: roof, rules: [no]).contains { $0.party.name == "Kramer" })
    }

    @Test("What is around a name is not the name", arguments: [
        ("Frau Dr. Petra Lindner (Mimi)", "Petra Lindner"),
        ("Frau Kurz (anna.kurz@firma.example)", "Kurz"),
        ("Süß, Sebastian", "Sebastian Süß"),
        ("'Jan Kramer'", "Jan Kramer"),
        ("Dr. Maria / Mimi", "Maria"),
        ("Hausverwaltung Brenner GmbH", "Hausverwaltung Brenner GmbH"),
    ])
    func cores(written: String, core: String) {
        #expect(PartyNames.core(written) == core)
    }
}

