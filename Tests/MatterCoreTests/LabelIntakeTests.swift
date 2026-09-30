import Foundation
import Testing
@testable import MatterCore

/// A mailbox in memory: folders of raw mails, searched the way a server would.
actor FakeMailbox: ReadOnlyMailbox {
    struct Stored { var uid: UInt32; var thread: String?; var raw: String }
    let isGmail: Bool
    let folderList: [MailFolder]
    let content: [String: [Stored]]
    private var open: String?
    private(set) var wholeFetches: [String: [UInt32]] = [:]

    init(gmail: Bool, folders: [MailFolder], content: [String: [Stored]]) {
        isGmail = gmail
        folderList = folders
        self.content = content
    }

    func folders() async throws -> [MailFolder] { folderList }

    func examine(_ folder: String) async throws -> OpenedFolder {
        open = folder
        return OpenedFolder(name: folder, uidValidity: 7, exists: content[folder]?.count ?? 0)
    }

    func search(_ keys: [SearchKey]) async throws -> [UInt32] {
        (content[open ?? ""] ?? []).filter { stored in
            let headers = EMLParser.parseHeaders(stored.raw)
            return keys.allSatisfy { key in
                switch key {
                case .all, .since: true
                case .gmailThread(let thread): stored.thread == thread
                case .messageID(let id): (headers["message-id"]?.first ?? "").contains(id)
                case .replies(let id):
                    ((headers["references"] ?? []) + (headers["in-reply-to"] ?? [])).joined(separator: " ").contains("<\(id)>")
                }
            }
        }.map(\.uid)
    }

    func fetch(_ uids: [UInt32], _ part: FetchPart) async throws -> [FetchedMessage] {
        let folder = open ?? ""
        if case .whole = part { wholeFetches[folder, default: []] += uids }
        return (content[folder] ?? []).filter { uids.contains($0.uid) }.map { stored in
            switch part {
            case .whole:
                return FetchedMessage(uid: stored.uid, gmailThread: stored.thread, data: Data(stored.raw.utf8))
            case .messageID:
                let id = EMLParser.parseHeaders(stored.raw)["message-id"]?.first ?? ""
                return FetchedMessage(uid: stored.uid, gmailThread: isGmail ? stored.thread : nil, data: Data("Message-ID: \(id)\r\n\r\n".utf8))
            case .threading:
                let headers = EMLParser.parseHeaders(stored.raw)
                let lines = ["message-id": "Message-ID", "in-reply-to": "In-Reply-To", "references": "References"]
                    .compactMap { key, name in headers[key]?.first.map { "\(name): \($0)\r\n" } }.joined()
                return FetchedMessage(uid: stored.uid, gmailThread: nil, data: Data((lines + "\r\n").utf8))
            }
        }
    }
}

@Suite("The daily door: one label, and the replies that followed it")
struct LabelIntakeTests {
    static let first = """
    Message-ID: <a@berger-hv.example>
    From: Hausverwaltung Berger <noreply@berger-hv.example>
    Date: Mon, 1 Sep 2026 09:00:00 +0200
    Subject: Sonderumlage Dach

    Bitte bis 30.11. zahlen.
    """
    static let reply = """
    Message-ID: <b@owner.example>
    From: Owner <owner@gmail.com>
    In-Reply-To: <a@berger-hv.example>
    References: <a@berger-hv.example>
    Date: Tue, 2 Sep 2026 10:00:00 +0200
    Subject: Re: Sonderumlage Dach

    Mache ich.
    """
    static let replyToReply = """
    Message-ID: <c@berger-hv.example>
    From: Hausverwaltung Berger <noreply@berger-hv.example>
    In-Reply-To: <b@owner.example>
    References: <b@owner.example>
    Date: Wed, 3 Sep 2026 10:00:00 +0200
    Subject: AW: Re: Sonderumlage Dach
    List-Unsubscribe: <https://berger-hv.example/abmelden>

    Danke.
    """
    static let unrelated = """
    Message-ID: <z@shop.example>
    From: Shop <info@shop.example>
    Date: Wed, 3 Sep 2026 11:00:00 +0200
    Subject: Re: Sonderumlage Dach

    Same subject, different thread.
    """

    @Test("Gmail: the thread Gmail knows brings the reply in, and the labelled mail is not read twice")
    func gmailThread() async throws {
        let mailbox = FakeMailbox(gmail: true, folders: [
            MailFolder(name: "INBOX"), MailFolder(name: "Matterbee"),
            MailFolder(name: "[Gmail]/All Mail", attributes: ["\\All"]),
        ], content: [
            "Matterbee": [.init(uid: 1, thread: "100", raw: Self.first)],
            "[Gmail]/All Mail": [.init(uid: 10, thread: "100", raw: Self.first),
                                 .init(uid: 11, thread: "100", raw: Self.reply),
                                 .init(uid: 12, thread: "200", raw: Self.unrelated)],
        ])
        let result = try await LabelIntake(label: "Matterbee", host: "imap.gmail.com").run(mailbox)

        #expect(result.emails.map(\.id) == ["a@berger-hv.example", "b@owner.example"])
        #expect(result.labelled == ["a@berger-hv.example"])
        #expect(result.followed == ["b@owner.example": .gmailThread])
        #expect(result.searched == ["[Gmail]/All Mail"])
        #expect(await mailbox.wholeFetches["[Gmail]/All Mail"] == [11])
        #expect(result.emails[0].source.absoluteString == "imap://imap.gmail.com/Matterbee;UIDVALIDITY=7/;UID=1")
    }

    @Test("Elsewhere: replies of replies by References, in the inbox and in sent mail; a shared subject is not enough")
    func references() async throws {
        let mailbox = FakeMailbox(gmail: false, folders: [
            MailFolder(name: "INBOX"), MailFolder(name: "Matterbee"), MailFolder(name: "Sent", attributes: ["\\Sent"]),
        ], content: [
            "Matterbee": [.init(uid: 1, raw: Self.first)],
            "Sent": [.init(uid: 5, raw: Self.reply)],
            "INBOX": [.init(uid: 8, raw: Self.replyToReply), .init(uid: 9, raw: Self.unrelated)],
        ])
        let result = try await LabelIntake(label: "matterbee", host: "imap.example").run(mailbox)

        #expect(Set(result.emails.map(\.id)) == ["a@berger-hv.example", "b@owner.example", "c@berger-hv.example"])
        #expect(result.followed.values.allSatisfy { $0 == .references })
        #expect(result.emails.map(\.id) == ["a@berger-hv.example", "b@owner.example", "c@berger-hv.example"])
    }

    @Test("Mail already known is not downloaded again, and its thread still brings the new reply in")
    func onlyTheNewOne() async throws {
        let mailbox = FakeMailbox(gmail: true, folders: [
            MailFolder(name: "Matterbee"), MailFolder(name: "[Gmail]/All Mail", attributes: ["\\All"]),
        ], content: [
            "Matterbee": [.init(uid: 1, thread: "100", raw: Self.first)],
            "[Gmail]/All Mail": [.init(uid: 10, thread: "100", raw: Self.first), .init(uid: 11, thread: "100", raw: Self.reply)],
        ])
        let result = try await LabelIntake(label: "Matterbee", host: "imap.gmail.com", known: ["a@berger-hv.example"]).run(mailbox)
        #expect(result.emails.map(\.id) == ["b@owner.example"])
        #expect(result.alreadyKnown == 1)
        #expect(await mailbox.wholeFetches["Matterbee"] == nil)
        #expect(await mailbox.wholeFetches["[Gmail]/All Mail"] == [11])
    }

    @Test("One mail read again by its pointer, or by its Message-ID when the pointer no longer fits")
    func fetchOne() async throws {
        let mailbox = FakeMailbox(gmail: true, folders: [
            MailFolder(name: "Matterbee"), MailFolder(name: "[Gmail]/All Mail", attributes: ["\\All"]),
        ], content: [
            "Matterbee": [.init(uid: 1, thread: "100", raw: Self.first)],
            "[Gmail]/All Mail": [.init(uid: 11, thread: "100", raw: Self.reply)],
        ])
        let direct = try await MailFetch.message(pointer: "imap://imap.gmail.com/Matterbee;UIDVALIDITY=7/;UID=1",
                                                 messageID: "a@berger-hv.example", from: mailbox)
        #expect(String(decoding: direct, as: UTF8.self).contains("Sonderumlage"))
        // The label was taken off: the pointer finds nothing, All Mail still has it.
        let moved = try await MailFetch.message(pointer: "imap://imap.gmail.com/Matterbee;UIDVALIDITY=99/;UID=5",
                                                messageID: "b@owner.example", from: mailbox)
        #expect(String(decoding: moved, as: UTF8.self).contains("Mache ich"))
    }

    @Test("A label that is not there says which ones are")
    func noSuchLabel() async {
        let mailbox = FakeMailbox(gmail: true, folders: [
            MailFolder(name: "INBOX"), MailFolder(name: "Verträge"), MailFolder(name: "[Gmail]", attributes: ["\\Noselect"]),
        ], content: [:])
        await #expect {
            _ = try await LabelIntake(label: "Matterbee", host: "imap.gmail.com").run(mailbox)
        } throws: { error in
            let text = "\(error)"
            return text.contains("Verträge") && !text.contains("[Gmail]\n")
        }
    }

    @Test("The filter does not overrule a label, but it still decides for a reply that came by thread")
    func labelOverrulesFilter() {
        let spike = Spike(detector: EntityDetector(runsTagger: false))
        let url = URL(string: "imap://imap.gmail.com/Matterbee;UIDVALIDITY=7/;UID=1")!
        let first = EMLParser.parse(source: Self.first, url: url)
        let later = EMLParser.parse(source: Self.replyToReply, url: url)
        let report = spike.run(emails: [first, later], labelled: [first.id])

        #expect(report.outcomes[0].judgement.isBulk == false)
        #expect(report.outcomes[1].judgement.isBulk == true)
        #expect(report.outcomes[0].judgement.source == url.absoluteString)
    }
}
