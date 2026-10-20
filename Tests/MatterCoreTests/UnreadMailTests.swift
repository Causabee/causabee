import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Unread mail: asked of the mailbox, never changed there")
@MainActor
struct UnreadMailTests {
    @Test("UNSEEN is a search, on the read-only list; nothing that sets a flag can be sent")
    func readOnly() throws {
        #expect(try IMAPClient.criterion(.unseen) == "UNSEEN")
        #expect(IMAPClient.allowed.contains("UID SEARCH"))
        #expect(!IMAPClient.allowed.contains("STORE") && !IMAPClient.allowed.contains("UID STORE"))
    }

    @Test("At a check, each mail of the last year gets the mailbox's word: unread or not; a scan and an old mail are not asked about")
    func refresh() async throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama")
        context.insert(matter)
        func mail(_ uid: Int, days: Double, kind: Source.Kind = .mail) -> Entry {
            let pointer = kind == .mail ? "imap://mail.example/INBOX;UIDVALIDITY=7/;UID=\(uid)" : "/Users/r/scan\(uid).pdf"
            let entry = Entry(title: "Mail \(uid)", from: "a@example.com", date: Date().addingTimeInterval(-days * 86_400),
                              source: Source(kind: kind, pointer: pointer, messageID: "<\(uid)@x>"))
            entry.matter = matter
            context.insert(entry)
            return entry
        }
        let new = mail(1, days: 1), read = mail(2, days: 2), old = mail(3, days: 400), scan = mail(4, days: 1, kind: .document)
        read.isUnread = true
        try context.save()
        let raw = { (uid: Int) in "Message-ID: <\(uid)@x>\r\nSubject: Mail \(uid)\r\n\r\nHi" }
        let mailbox = FakeMailbox(gmail: false, folders: [MailFolder(name: "INBOX")], content: ["INBOX": [
            .init(uid: 1, thread: nil, raw: raw(1), seen: false), .init(uid: 2, thread: nil, raw: raw(2), seen: true),
            .init(uid: 3, thread: nil, raw: raw(3), seen: false),
        ]])
        #expect(await UnreadMail.refresh(from: mailbox, in: context) == 2)
        #expect(new.isUnread == true)
        #expect(read.isUnread == false)
        #expect(old.isUnread == nil)
        #expect(scan.isUnread == nil)
        #expect(matter.unreadMails.map(\.title) == ["Mail 1"])
        #expect(await UnreadMail.refresh(from: mailbox, in: context) == 0)
    }
}
