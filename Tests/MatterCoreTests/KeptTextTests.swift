import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The kept words of mails and files are the same on every device")
@MainActor
struct KeptTextTests {
    @Test("What one device kept goes into the store; another device gets it beside its own store; forgotten, it is gone")
    func sharedBothWays() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama")
        context.insert(matter)
        let source = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<a@x>", date: Date())
        let entry = Entry(title: "Pflegegrad", from: "Kasse <k@x.example>", date: Date(), source: source)
        entry.matter = matter
        context.insert(entry)
        try context.save()
        let mac = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("matters.store")
        let phone = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("matters.store")
        let email = Email(source: mac, id: "<a@x>", headers: [:], subject: "Pflegegrad", from: "Kasse <k@x.example>", to: [], cc: [],
                          date: nil, body: "Der Gutachter kommt am 6. Oktober.", attachments: [])
        MailText.save(email, besides: mac)
        #expect(KeptTexts.share(besides: mac, in: context) == (1, 0))
        #expect(KeptTexts.share(besides: mac, in: context) == (0, 0))
        #expect(KeptTexts.share(besides: phone, in: context) == (0, 1))
        #expect(MailText.load("<a@x>", besides: phone)?.body == "Der Gutachter kommt am 6. Oktober.")
        KeptTexts.forget("<a@x>", in: context)
        #expect(try context.fetchCount(FetchDescriptor<KeptText>()) == 0)
    }
}
