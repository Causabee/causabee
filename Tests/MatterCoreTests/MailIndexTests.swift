import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("A matter's mails by Message-ID: found at once, and never a mail that has left")
@MainActor
struct MailIndexTests {
    @Test("Found; a mail moved out and another in — the same count — is told apart; a file's digest comes from its mail")
    func index() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let one = Matter(key: "one"), two = Matter(key: "two")
        context.insert(one); context.insert(two)
        func mail(_ id: String, in matter: Matter) -> Entry {
            let entry = Entry(title: id, from: "a@example.com", date: Date(), source: Source(kind: .mail, pointer: "p\(id)", messageID: id))
            entry.matter = matter
            context.insert(entry)
            return entry
        }
        let a = mail("<a@x>", in: one), b = mail("<b@x>", in: one), c = mail("<c@x>", in: two)
        try context.save()
        #expect(one.entry(messageID: "<a@x>") === a)
        #expect(one.entry(messageID: "<c@x>") == nil)
        // b goes to two, c comes to one: one still has two mails.
        b.matter = two
        c.matter = one
        try context.save()
        #expect(one.entry(messageID: "<b@x>") == nil)
        #expect(one.entry(messageID: "<c@x>") === c)
        #expect(two.entry(messageID: "<b@x>") === b)
        let scan = Source(kind: .document, pointer: "/scan.pdf", messageID: "<a@x>")
        let file = Document(name: "scan.pdf", contentType: "application/pdf", byteCount: 1, source: scan)
        file.matter = one
        context.insert(file)
        a.digest = "A letter from the insurer."
        try context.save()
        #expect(file.says == "A letter from the insurer.")
    }
}
