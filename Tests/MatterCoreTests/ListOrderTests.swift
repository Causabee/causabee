import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The same matter always lists in the same order")
@MainActor
struct ListOrderTests {
    func mail(_ id: String, day: Int, parties: [String]) throws -> Judgement {
        let json: [String: Any] = [
            "email_id": id, "source": "imap://x;UID=\(day)", "date": "2026-09-\(String(format: "%02d", day))T10:00:00Z",
            "subject": "Mail \(id)", "from": "x@example.org", "is_bulk": false, "matter": "garten", "matter_confidence": 0.9,
            "matter_reason": "", "decided_by": "claude", "todos": [], "deadlines": [], "appointments": [], "done": [],
            "parties": parties.map { ["name": $0, "role": "Nachbar", "is_new": true] },
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("People named most often first; people named as often by name")
    func people() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply([
            try mail("a", day: 1, parties: ["Zora Winter", "Mia Adler", "Ben Kurz"]),
            try mail("b", day: 2, parties: ["Ben Kurz"]),
        ], to: context, owner: [])
        let matter = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        #expect(MatterStatus(matter).memberships.compactMap(\.party?.name) == ["Ben Kurz", "Mia Adler", "Zora Winter"])
    }
}
