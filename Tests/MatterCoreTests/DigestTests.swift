import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("A mail's digest, the thread in the store, the text kept on the Mac")
@MainActor
struct DigestTests {
    func judgement(_ extra: [String: Any]) throws -> Judgement {
        var json: [String: Any] = [
            "email_id": "dachrinne-1@example.org", "source": "imap://imap.gmail.com/matterbee;UIDVALIDITY=7/;UID=3",
            "date": "2026-09-18T10:00:00Z", "subject": "Lieferung Dachrinne", "from": "Petra Lindner <petra@example.org>",
            "is_bulk": false, "matter": "dach", "matter_confidence": 0.9, "matter_reason": "", "decided_by": "claude",
            "parties": [], "todos": [], "deadlines": [], "appointments": [], "done": [],
        ]
        json.merge(extra) { $1 }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("From the sorting answer to the entry, and into what the assistant is shown; an old record has none")
    func digest() throws {
        let old = try judgement([:])
        #expect(old.digest == nil)
        let new = try judgement(["digest": "Die Dachrinne kommt am 2. Oktober; die Gebäudeversicherung zahlt 80 Euro dazu."])
        let encoded = try JSONEncoder().encode(new)
        #expect(String(decoding: encoded, as: UTF8.self).contains("\"digest\""))

        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply([new], to: context, owner: ["Jan Kramer"])
        let entry = try #require(try context.fetch(FetchDescriptor<Entry>()).first)
        #expect(entry.digest?.contains("80 Euro") == true)
        let matter = try #require(entry.matter)
        let facts = FactSheet.facts(for: [matter], today: "2026-09-29")
        #expect(facts.text.contains("Lieferung Dachrinne — Die Dachrinne kommt am 2. Oktober"))
    }

    @Test("Only mail from the label with no digest asked for yet is read again")
    func missing() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        func entry(_ id: String, pointer: String, digest: String?) {
            let entry = Entry(title: id, from: "x@example.org", date: Date(), source: Source(kind: .mail, pointer: pointer, messageID: id))
            entry.digest = digest
            context.insert(entry)
        }
        entry("a", pointer: "imap://x;UID=1", digest: nil)
        entry("b", pointer: "imap://x;UID=2", digest: "Schon da.")
        entry("c", pointer: "imap://x;UID=3", digest: "")          // asked: nothing worth keeping
        entry("d", pointer: "/Users/x/Desktop/chat.png", digest: nil) // not from the label
        try context.save()
        #expect(DigestBackfill.missing(in: context).map(\.messageID) == ["a"])
    }

    @Test("A turn is a record of its own, and follows its matter into a merge")
    func thread() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let a = Matter(key: "dach"), b = Matter(key: "dach-2")
        context.insert(a); context.insert(b)
        let turn = ThreadTurn(id: UUID(), date: Date(), payload: Data("{}".utf8))
        context.insert(turn)
        turn.matter = b
        try context.save()
        a.absorb(b, in: context)
        try context.save()
        #expect(turn.matter === a)
        #expect(try context.fetch(FetchDescriptor<ThreadTurn>()).count == 1)
    }

    @Test("The mail's words are kept beside the store, under a name from its Message-ID")
    func text() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("digest-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = folder.appendingPathComponent("matters.store")
        let email = Email(source: URL(fileURLWithPath: "/x.eml"), id: "dachrinne-1@example.org", headers: [:], subject: "Lieferung",
                          from: "Petra Lindner <petra@example.org>", to: ["jan@example.com"], cc: [], date: nil,
                          body: "Die Dachrinne kommt am Donnerstag.", attachments: [])
        #expect(!MailText.has(email.id, besides: store))
        MailText.save(email, besides: store)
        #expect(MailText.has(email.id, besides: store))
        let saved = try String(contentsOf: MailText.url(for: email.id, besides: store), encoding: .utf8)
        #expect(saved.contains("Subject: Lieferung") && saved.hasSuffix("Die Dachrinne kommt am Donnerstag."))
        #expect(MailText.url(for: email.id, besides: store).deletingLastPathComponent().lastPathComponent == "Mail-Text")
    }
}
