import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Links in a matter: named, opened by the owner, never shown to the assistant by address")
@MainActor
struct LinkTests {
    @Test("What kind of page a link is, from its address alone", arguments: [
        ("https://docs.google.com/document/d/1AbC/edit", "Google Doc"),
        ("https://docs.google.com/spreadsheets/d/1AbC/edit#gid=0", "Google Sheet"),
        ("https://docs.google.com/presentation/d/1AbC/edit", "Google Slides"),
        ("https://drive.google.com/drive/folders/1AbC", "Google Drive"),
        ("https://www.example.org/seite", "example.org"),
    ])
    func kinds(address: String, kind: String) {
        #expect(WebLink.kind(of: URL(string: address)) == kind)
    }

    @Test("A web address is found in what was pasted; anything else is not one")
    func addresses() {
        #expect(WebLink.address(in: "  https://docs.google.com/document/d/1AbC/edit \n") == "https://docs.google.com/document/d/1AbC/edit")
        #expect(WebLink.address(in: "docs.google.com/document/d/1AbC") == "https://docs.google.com/document/d/1AbC")
        #expect(WebLink.address(in: "Kostenaufstellung") == nil)
        #expect(WebLink.address(in: "file:///Users/x/a.pdf") == nil)
        #expect(WebLink.address(in: "") == nil)
    }

    @Test("The assistant hears the name and the kind, never the address; a merged matter keeps its links")
    func facts() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "sperrmuell"), other = Matter(key: "sperrmuell-2")
        context.insert(matter); context.insert(other)
        let todo = Todo(text: "Liste an Georg schicken", owner: .me, due: nil,
                        source: Source(kind: .mail, pointer: "x", messageID: "a@example"), origin: "a#1")
        context.insert(todo)
        todo.matter = matter
        let list = WebLink(address: "https://docs.google.com/spreadsheets/d/SECRET123/edit", title: "Liste Sperrmüll")
        let plan = WebLink(address: "https://docs.google.com/document/d/SECRET456/edit")
        context.insert(list); context.insert(plan)
        list.matter = matter; list.todo = todo
        plan.matter = other
        try context.save()

        let facts = FactSheet.facts(for: [matter], today: "2026-09-28")
        #expect(facts.text.contains("Liste an Georg schicken") && facts.text.contains("linked: Liste Sperrmüll (Google Sheet)"))
        #expect(!facts.text.contains("SECRET") && !facts.text.contains("docs.google.com"))
        #expect(facts.ownerText.contains("Liste Sperrmüll"))
        #expect(todo.isMessage)

        matter.absorb(other, in: context)
        try context.save()
        let merged = FactSheet.facts(for: [matter], today: "2026-09-28")
        #expect(merged.text.contains("- a Google Doc, not named"))
        #expect(!merged.text.contains("SECRET"))
    }

    @Test("A web address typed in a question is sent as [Link 1] and comes back as itself")
    func typedAddress() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "dach")
        context.insert(matter)
        try context.save()
        let mapping = FileManager.default.temporaryDirectory.appendingPathComponent("mapping-\(UUID()).json")
        try JSONEncoder().encode(Pseudonymizer.Mapping()).write(to: mapping)
        let address = "https://docs.google.com/document/d/1XyZsecret0815/edit?tab=t.abc"
        let prepared = try AssistantAsk.prepare(question: "Hier der Link: \(address). Bitte speichern.", inHand: nil, earlier: [],
                                                facts: FactSheet.facts(for: [matter], today: "2026-09-28"), owner: nil,
                                                today: "2026-09-28", mapping: mapping, saves: false)
        #expect(!prepared.sent.contains("1XyZsecret0815") && !prepared.sent.contains("docs.google.com"))
        #expect(prepared.sent.contains("Hier der Link: [Link 1]. Bitte speichern."))
        #expect(prepared.links == ["[Link 1]": address])
    }

    @Test("A note's line with an address becomes a named link, and leaves the note")
    func fromNote() {
        let note = "Termin mit Dachdeckerin klären\nLink zum Dokument 'Umzug Liste': https://docs.google.com/document/d/1AbC/edit?tab=t.9"
        let (links, rest) = WebLink.split(note: note)
        #expect(links.count == 1)
        #expect(links.first?.address == "https://docs.google.com/document/d/1AbC/edit?tab=t.9")
        #expect(links.first?.title == "Umzug Liste")
        #expect(rest == "Termin mit Dachdeckerin klären")
        #expect(WebLink.split(note: "https://example.org/a").rest == nil)
    }
}
