import Foundation
import SwiftData
import Testing
@testable import MatterCore

@MainActor
struct SortedMailsKnownTests {
    @Test func mailInAMatterOrLeftOutOnAnotherDeviceCountsAsKnown() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let source = Source(kind: .mail, pointer: "p", messageID: "in-a-matter@x", date: Date())
        let entry = Entry(title: "Hi", from: "a@x", date: Date(), source: source)
        entry.messageID = "in-a-matter@x"
        context.insert(entry)
        SortedMails.setAside(["left-out@x"], device: "iPad", in: context)
        let known = SortedMails.known(in: context)
        #expect(known.contains("in-a-matter@x"))
        #expect(known.contains("left-out@x"))
        #expect(!known.contains("new@x"))
    }
}
