import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Three open matters free; a fourth waits, nothing is locked")
@MainActor
struct PlanTests {
    func judgement(_ id: String, matter: String) throws -> Judgement {
        let json: [String: Any] = [
            "email_id": id, "source": "imap://x/;UID=1", "date": "2026-10-21T10:00:00Z", "subject": "S", "from": "A <a@example.org>",
            "is_bulk": false, "matter": matter, "matter_title": matter.capitalized, "matter_confidence": 0.9, "matter_reason": "",
            "decided_by": "claude", "parties": [], "todos": [], "deadlines": [], "appointments": [], "done": [],
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("Room by plan: free counts open matters, the others have none to count")
    func room() {
        #expect(Plan.free.room(open: 1) == 2)
        #expect(Plan.free.room(open: 5) == 0)
        #expect(Plan.matters.room(open: 9) == nil && Plan.pro.room(open: 9) == nil)
        #expect(Plan.free < .matters && Plan.matters < .pro)
    }

    @Test("Mail for a matter already there comes in; one that would start a matter beyond the room waits")
    func held() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply([try judgement("a", matter: "flat")], to: context)
        let summary = try MatterImport.apply([try judgement("b", matter: "flat"), try judgement("c", matter: "trip"), try judgement("d", matter: "car")],
                                             to: context, room: 1)
        #expect(summary.mattersNew == 1 && summary.held == ["d"])
        #expect(try context.fetch(FetchDescriptor<Matter>()).map(\.key).sorted() == ["flat", "trip"])
        let waiting = try judgement("d", matter: "car").waitingForRoom()
        #expect(waiting.matter == nil && waiting.matterReason.contains("Car"))
    }
}
