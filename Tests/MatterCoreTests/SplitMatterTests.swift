import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("New mail of a closed matter, as a matter of its own")
@MainActor
struct SplitMatterTests {
    func mail(_ id: String, day: Int, subject: String, from: String, todos: [String], deadline: String? = nil) throws -> Judgement {
        let json: [String: Any] = [
            "email_id": id, "source": "imap://x;UID=\(day)", "date": "2026-09-\(String(format: "%02d", day))T10:00:00Z",
            "subject": subject, "from": from, "is_bulk": false, "matter": "bewerbung", "matter_confidence": 0.9,
            "matter_reason": "", "decided_by": "claude", "done": [], "appointments": [],
            "todos": todos.map { ["text": $0, "owner": "me", "source_quote": $0] },
            "deadlines": deadline.map { [["what": $0, "date": "2026-10-20", "source_quote": $0]] } ?? [],
            "parties": [["name": "Robbie Kerr", "role": "Recruiter", "is_new": true]],
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("Only what the new mails brought moves; a task an old mail said too stays; the people are in both")
    func split() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply([try mail("old", day: 1, subject: "Bewerbung", from: "Shine <jobs@shine.example>",
                                             todos: ["Unterlagen schicken"])], to: context)
        let old = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        old.closedAt = ISO8601DateFormatter().date(from: "2026-09-05T00:00:00Z")
        try context.save()
        _ = try MatterImport.apply([
            try mail("new1", day: 10, subject: "Einladung: Robbie Kerr", from: "Robbie Kerr <robbie@shine.example>",
                     todos: ["Termin bestätigen", "Unterlagen schicken"], deadline: "Antwort bis"),
            try mail("new2", day: 11, subject: "Re: Einladung: Robbie Kerr", from: "Robbie Kerr <robbie@shine.example>",
                     todos: ["Raum buchen"]),
        ], to: context)
        // The old mail's task, said again by a new one: it belongs to both, so it stays.
        let shared = try #require((old.todos ?? []).first { $0.origin.hasPrefix("old#") })
        shared.sources.append(Source(kind: .mail, pointer: "imap://x;UID=10", messageID: "new1", date: nil))
        try context.save()
        let moved = MatterStatus(old).mailsSinceClosed
        #expect(moved.map(\.messageID).sorted() == ["new1", "new2"])

        let new = try old.split(moved, intoNewMatterNamed: "Einladung Robbie Kerr", turnsSince: old.closedAt, in: context)
        #expect(new.name == "Einladung Robbie Kerr")
        #expect(Set((new.entries ?? []).map(\.messageID)) == ["new1", "new2"])
        #expect((old.entries ?? []).map(\.messageID) == ["old"])
        // new1's own "Unterlagen schicken" is a task of its own, and goes; the shared one stays.
        #expect(Set((new.todos ?? []).map(\.origin)) == ["new1#termin bestätigen", "new1#unterlagen schicken", "new2#raum buchen"])
        #expect((old.todos ?? []).map(\.origin) == ["old#unterlagen schicken"])
        #expect((new.deadlines ?? []).map(\.what) == ["Antwort bis"])
        #expect(new.parties.map(\.name).contains("Robbie Kerr"))
        #expect(old.parties.map(\.name).contains("Robbie Kerr"))
        #expect(MatterStatus(old).mailsSinceClosed.isEmpty)
        #expect(new.closedAt == nil)
    }
}
