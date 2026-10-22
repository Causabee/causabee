import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Fewer things from mail: a moved call changes the one on file, what is taken out is not suggested again")
@MainActor
struct FewerThingsTests {
    func judgement(_ id: String, _ extra: [String: Any]) throws -> Judgement {
        var json: [String: Any] = [
            "email_id": id, "source": "imap://x/;UID=1", "date": "2026-10-21T10:00:00Z", "subject": "Call", "from": "A <a@example.org>",
            "is_bulk": false, "matter": "job", "matter_confidence": 0.9, "matter_reason": "", "decided_by": "claude",
            "parties": [], "todos": [], "deadlines": [], "appointments": [], "done": [],
        ]
        json.merge(extra) { $1 }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("A call moved from 11:00 to 10:00 is one call, at 10:00")
    func moved() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let first = try judgement("m1", ["appointments": [["what": "Call", "date": "2026-10-23", "time": "11:00", "place": NSNull(), "source_quote": "11:00"]]])
        let second = try judgement("m2", ["appointments": [["what": "Call with the decision", "date": "2026-10-23", "time": "10:00", "place": NSNull(),
                                                            "source_quote": "10:00 then", "replaces": "2026-10-23 11:00"]]])
        _ = try MatterImport.apply([first], to: context)
        _ = try MatterImport.apply([second], to: context)
        let all = try context.fetch(FetchDescriptor<Appointment>())
        #expect(all.count == 1)
        #expect(all.first?.time == "10:00" && all.first?.what == "Call with the decision" && all.first?.sources.count == 2)
    }

    @Test("A task from mail deleted by hand is remembered as not wanted; on file for the next mail")
    func unwanted() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let found = try judgement("m1", ["todos": [["text": "Attend the call", "owner": "me", "due": "2026-10-23", "source_quote": "call", "same_as": NSNull()]],
                                         "appointments": [["what": "Call", "date": "2099-10-23", "time": "10:00", "place": NSNull(), "source_quote": "10:00"]]])
        _ = try MatterImport.apply([found], to: context)
        let todo = try #require(try context.fetch(FetchDescriptor<Todo>()).first)
        context.deleteByHand([todo], undo: nil, named: "Delete Task")
        let matter = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        #expect(matter.shownBrief?.unwanted == ["Attend the call"])
        let file = try #require(Unplaced.onFile(in: context)["job"])
        #expect(file.unwanted == ["Attend the call"] && file.appointments == ["2099-10-23 10:00 — Call"])
        // And the model is shown both.
        let user = ExtractionPrompt.user(mail: "x", sent: nil, owner: [], matters: [], thread: "job",
                                         onFile: Extractor.shown(["job": file], for: "job", from: nil))
        #expect(user.contains("2099-10-23 10:00 — Call") && user.contains("- Attend the call"))
    }

    @Test("What others do is in its matter, not on the owner's day")
    func waiting() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let found = try judgement("m1", ["todos": [
            ["text": "Send the certificate", "owner": "me", "due": "2026-10-23", "source_quote": "a", "same_as": NSNull()],
            ["text": "They call the references", "owner": "other", "due": "2026-10-23", "source_quote": "b", "same_as": NSNull()],
        ]])
        _ = try MatterImport.apply([found], to: context)
        let matters = try context.fetch(FetchDescriptor<Matter>())
        #expect(Week.things(on: "2026-10-23", in: matters).map(\.what) == ["Send the certificate"])
    }

    @Test("Shown on file: the thread's matter only, appointments from the day before the mail on")
    func shown() {
        let files = ["job": Extractor.OnFile(appointments: ["2026-10-01 09:00 — Old", "2026-10-23 10:00 — Call"], unwanted: []),
                     "flat": Extractor.OnFile(appointments: [], unwanted: ["Read the contract"])]
        let sent = ISO8601DateFormatter().date(from: "2026-10-21T10:00:00Z")
        let one = Extractor.shown(files, for: "job", from: sent)
        #expect(one.count == 1 && one[0].appointments == ["2026-10-23 10:00 — Call"])
        #expect(Extractor.shown(files, for: nil, from: sent).map(\.matter) == ["flat", "job"])
    }
}
