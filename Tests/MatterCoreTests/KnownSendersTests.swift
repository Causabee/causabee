import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Whose mail is offered without a label")
@MainActor
struct KnownSendersTests {
    @Test("The people of matters going on and of those closed in the last two months; a matter closed longer sleeps")
    func awake() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        func matter(_ key: String, _ address: String?, closedDaysAgo: Double?) {
            let matter = Matter(key: key)
            context.insert(matter)
            let party = Party(name: key)
            party.address = address
            context.insert(party)
            let membership = Membership()
            context.insert(membership)
            membership.party = party
            membership.matter = matter
            if let closedDaysAgo { matter.closedAt = Date().addingTimeInterval(-closedDaysAgo * 86_400) }
        }
        matter("open", "Tanguy@Doctolib.example ", closedDaysAgo: nil)
        matter("lately", "anna@x.example", closedDaysAgo: 20)
        matter("asleep", "old@x.example", closedDaysAgo: 90)
        matter("nameonly", nil, closedDaysAgo: nil)
        // Someone who came in with mail has no address of their own: the one they wrote from counts.
        let wrote = try #require(try context.fetch(FetchDescriptor<Matter>()).first { $0.key == "nameonly" })
        for (from, id) in [("Nameonly <N.Only@Firm.example>", "1"), ("A Stranger <stranger@else.example>", "2")] {
            let entry = Entry(title: "Hello", from: from, date: Date(), source: Source(kind: .mail, pointer: "imap://x;UID=" + id, messageID: id, date: Date()))
            context.insert(entry)
            entry.matter = wrote
        }
        let all = try context.fetch(FetchDescriptor<Matter>())
        #expect(KnownSenders.addresses(in: all) == ["anna@x.example", "n.only@firm.example", "tanguy@doctolib.example"])
    }
}
