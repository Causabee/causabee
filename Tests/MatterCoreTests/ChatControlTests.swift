import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// Full control from the chat (9 November): every element of a matter can be seen by the bee, by an
/// id, and put away, changed, moved, opened again — and each undone.
@Suite("The chat controls everything a matter holds")
@MainActor
struct ChatControlTests {
    final class World {
        let context: ModelContext
        let matter: Matter, other: Matter
        let todo: Todo, info: Todo, appointment: Appointment, deadline: Deadline
        let note: MatterNote, detail: MatterDetail, link: WebLink, file: Document, decision: Decision
        let party: Party

        init() throws {
            context = ModelContext(try MatterSchema.container(at: nil))
            matter = Matter(key: "car", name: "Volvo or VW"); other = Matter(key: "mum", name: "Care for Mum")
            context.insert(matter); context.insert(other)
            let mail = Source(kind: .mail, pointer: "imap://x", messageID: "m1@dealer", date: Date())
            todo = Todo(text: "Versicherung anfragen", owner: .me, due: nil, source: mail, origin: "m1#1")
            info = Todo(text: "Das Angebot enthält einen Rabatt", owner: .me, due: nil, source: mail, origin: "m1#2"); info.isInfo = true
            appointment = Appointment(what: "Probefahrt", day: "2026-11-13", time: "14:30", place: nil, source: mail)
            appointment.endTime = "17:30"
            deadline = Deadline(what: "Angebot gültig", day: "2026-11-20", source: mail)
            note = MatterNote(text: "Frau will den Volvo")
            detail = MatterDetail(label: "Kundennummer", value: "4711")
            link = WebLink(address: "https://example.org/offer", title: "Angebot online")
            file = Document(name: "Angebot.pdf", contentType: "application/pdf", byteCount: 2_000_000, source: mail)
            decision = Decision(what: "Wir nehmen den VW", why: "günstiger")
            party = Party(name: "Hannes Kroeger")
            let membership = Membership(); membership.party = party; membership.matter = matter
            for model: any PersistentModel in [todo, info, appointment, deadline, note, detail, link, file, decision, party, membership] { context.insert(model) }
            todo.matter = matter; info.matter = matter; appointment.matter = matter; deadline.matter = matter
            note.matter = matter; detail.matter = matter; link.matter = matter; file.matter = matter; decision.matter = matter
            try context.save()
        }

        var all: [(String, any PersistentModel)] {
            [("task", todo), ("info", info), ("appointment", appointment), ("deadline", deadline), ("note", note),
             ("detail", detail), ("link", link), ("file", file)]
        }
    }

    @Test("The bee sees every element by an id it can name back")
    func everythingHasAnId() throws {
        let w = try World()
        let facts = FactSheet.facts(for: [w.matter], today: "2026-11-09")
        #expect(facts.text.contains("id=\"M1\""))
        for prefix in ["T1", "A1", "D1", "P1", "N1", "X1", "L1", "F1", "C1"] {
            #expect(facts.text.contains(prefix + " "), "\(prefix) is not in the facts")
        }
        #expect(facts.refs["N1"] == .note(w.note.persistentModelID))
        #expect(facts.refs["X1"] == .detail(w.detail.persistentModelID))
        #expect(facts.refs["L1"] == .link(w.link.persistentModelID))
        #expect(facts.refs["F1"] == .document(w.file.persistentModelID))
        #expect(facts.refs["C1"] == .decision(w.decision.persistentModelID))
        #expect(facts.text.contains("Wir nehmen den VW — why: günstiger"))
        #expect(facts.text.contains("14:30–17:30 · 3 h"), "How long is not in the facts")
        #expect(!facts.text.contains("4711"), "A detail's value went out")
        #expect(!facts.text.contains("Mails, newest first"))
    }

    @Test("Each element put away, and shown again", arguments: ["task", "info", "appointment", "deadline", "note", "detail", "link", "file"])
    func putAwayAndBack(kind: String) throws {
        let w = try World()
        let thing = try #require(w.all.first { $0.0 == kind }?.1)
        let result = ChatControl.putAway(thing, from: w.matter)
        #expect(result.done)
        #expect((thing as? Hideable)?.isHidden == true)
        #expect(!ChatControl.putAway(thing, from: w.matter).done, "Put away twice")
        ChatControl.showAgain(thing, in: w.matter, unwanted: result.unwanted)
        #expect((thing as? Hideable)?.isHidden == false)
        #expect(!(w.matter.shownBrief?.unwanted ?? []).contains { $0 == result.unwanted })
    }

    @Test("What came in and was put away is not suggested again — until it is shown again")
    func notWantedWhilePutAway() throws {
        let w = try World()
        let result = ChatControl.putAway(w.todo, from: w.matter)
        #expect(result.unwanted == "Versicherung anfragen")
        #expect((w.matter.shownBrief?.unwanted ?? []).contains("Versicherung anfragen"))
        ChatControl.showAgain(w.todo, in: w.matter, unwanted: result.unwanted)
        let after = w.matter.shownBrief?.unwanted ?? []
        #expect(!after.contains("Versicherung anfragen"))
    }

    @Test("A person taken off this matter, and back")
    func personOff() throws {
        let w = try World()
        #expect(ChatControl.putAway(w.party, from: w.matter).done)
        #expect(!w.matter.shownParties.contains { $0 === w.party })
        ChatControl.showAgain(w.party, in: w.matter, unwanted: nil)
        #expect(w.matter.shownParties.contains { $0 === w.party })
    }

    @Test("Each field changed, and set back as it was", arguments: [
        ("task", "text", "Versicherung bei HUK anfragen"), ("task", "note", "bis Freitag"), ("task", "kind", "info"),
        ("appointment", "text", "Probefahrt EX40"), ("appointment", "place", "Autohaus Nord"),
        ("deadline", "text", "Angebot gilt bis"), ("note", "text", "Frau will doch den VW"),
        ("detail", "label", "Kunden-Nr."), ("detail", "value", "4712"), ("link", "title", "Das Angebot"), ("file", "name", "VW-Angebot.pdf"),
    ])
    func changeAndRestore(kind: String, field: String, value: String) throws {
        let w = try World()
        let thing = try #require(w.all.first { $0.0 == kind }?.1)
        let before = try #require(ChatControl.change(thing, field: field, to: value), "\(kind).\(field) cannot be changed")
        #expect(ChatControl.fields(of: thing).contains(field))
        ChatControl.restore(thing, field: field, to: before)
        #expect(ChatControl.change(thing, field: field, to: value)?.value == before.value, "\(kind).\(field) not set back")
    }

    @Test("A person's phone and mail, the matter's name, a decision — changed and set back")
    func moreFields() throws {
        let w = try World()
        let phone = try #require(ChatControl.change(w.party, field: "phone", to: "0171 2345678"))
        #expect(w.party.phone == "0171 2345678")
        ChatControl.restore(w.party, field: "phone", to: phone)
        #expect(w.party.phone == nil)
        let name = try #require(ChatControl.change(w.matter, field: "name", to: "Neues Auto"))
        #expect(w.matter.name == "Neues Auto" && w.matter.aliases.contains("Volvo or VW"))
        ChatControl.restore(w.matter, field: "name", to: name)
        #expect(w.matter.name == "Volvo or VW" && !w.matter.aliases.contains("Neues Auto"))
        let why = try #require(ChatControl.change(w.decision, field: "why", to: "Platz für den Hund"))
        ChatControl.restore(w.decision, field: "why", to: why)
        #expect(w.decision.why == "günstiger")
    }

    @Test("What cannot be: an empty name, an unknown field, a kind that is neither — nothing changes, and it says so")
    func cannot() throws {
        let w = try World()
        #expect(ChatControl.change(w.todo, field: "text", to: "  ") == nil)
        #expect(ChatControl.change(w.todo, field: "colour", to: "red") == nil)
        #expect(ChatControl.change(w.todo, field: "kind", to: "maybe") == nil)
        #expect(ChatControl.change(w.matter, field: "name", to: "Volvo or VW") == nil)
        #expect(w.todo.text == "Versicherung anfragen")
    }

    @Test("An appointment's place set in the chat makes it the owner's")
    func placeIsOwners() throws {
        let w = try World()
        _ = ChatControl.change(w.appointment, field: "place", to: "Autohaus Nord")
        #expect(w.appointment.place == "Autohaus Nord" && w.appointment.isOwners)
    }

    @Test("Each element moved to another matter, and back", arguments: ["task", "appointment", "deadline", "note", "detail", "link", "file"])
    func moveAndBack(kind: String) throws {
        let w = try World()
        let thing = try #require(w.all.first { $0.0 == kind }?.1)
        let from = try #require(ChatControl.move(thing, into: w.other))
        #expect(from === w.matter)
        #expect(ChatControl.move(thing, into: w.other) == nil, "Moved where it already is")
        _ = ChatControl.move(thing, into: w.matter)
        #expect(ChatControl.move(thing, into: w.matter) == nil)
    }

    @Test("Another matter found by the name the owner says", arguments: ["Care for Mum", "care for mum", "Mum"])
    func matterByName(name: String) throws {
        let w = try World()
        #expect(ChatControl.matter(named: name, in: w.context) === w.other)
    }

    @Test("The next question is sent with what was offered before, taken or not")
    func earlierCards() throws {
        let json: [String: Any] = ["lines": [["text": "Ich setze die Probefahrt.", "cites": ["A1"]]],
                                   "cards": [["kind": "change_date", "text": "", "owner": "me", "todo": "A1", "due": "2026-11-13", "time": "14:30",
                                              "reason": "", "cites": []],
                                             ["kind": "put_away", "text": "", "owner": "me", "todo": "T1", "reason": "", "cites": []]]]
        let reply = try JSONDecoder().decode(AssistantPrompt.Reply.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(reply.cards.map(\.kind) == [.changeDate, .putAway])
        #expect(AssistantPrompt.system.contains("`put_away`") && AssistantPrompt.system.contains("`change_field`"))
        #expect(AssistantPrompt.system.contains("`move_to`") && AssistantPrompt.system.contains("`reopen`"))
    }
}
