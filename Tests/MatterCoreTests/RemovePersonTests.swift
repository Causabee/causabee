import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Taking a person out of a matter")
@MainActor
struct RemovePersonTests {
    func mail(_ id: String, day: Int) throws -> Judgement {
        let json: [String: Any] = [
            "email_id": id, "source": "imap://x;UID=\(day)", "date": "2026-09-\(String(format: "%02d", day))T10:00:00Z",
            "subject": "Mail \(id)", "from": "x@example.org", "is_bulk": false, "matter": "dach", "matter_confidence": 0.9,
            "matter_reason": "", "decided_by": "claude", "todos": [], "deadlines": [], "appointments": [], "done": [],
            "parties": [["name": "Petra Lindner", "role": "Gutachterin", "is_new": true], ["name": "Tom Brenner", "role": "Nachbar", "is_new": true]],
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("Gone from the matter, kept as a rule, and not brought back by the next mail")
    func remove() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply([try mail("a", day: 1)], to: context, owner: [])
        let matter = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        let tom = try #require(matter.memberships?.first { $0.party?.name == "Tom Brenner" })
        tom.remove(in: context, origin: "you, in dach")
        try context.save()
        #expect(matter.parties.map(\.name) == ["Petra Lindner"])

        _ = try MatterImport.apply([try mail("b", day: 2)], to: context, owner: [])
        #expect(matter.parties.map(\.name) == ["Petra Lindner"])
        let rule = try #require(try context.fetch(FetchDescriptor<Rule>()).first { $0.kind == .notInMatter })
        #expect(rule.subject == "Tom Brenner" && rule.fired == 1)

        rule.isOn = false
        _ = try MatterImport.apply([try mail("c", day: 3)], to: context, owner: [])
        #expect(Set(matter.parties.map(\.name)) == ["Petra Lindner", "Tom Brenner"])
    }
}
