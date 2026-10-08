import Foundation
import Testing
@testable import MatterCore

@Suite("A matter's mails as conversations")
struct MailThreadsTests {
    func mail(_ id: String, _ subject: String, from: String, day: Int, answers: String? = nil) -> Entry {
        let date = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
        let entry = Entry(title: subject, from: from, date: date, source: Source(kind: .mail, pointer: ""))
        entry.messageID = id
        entry.replyTo = answers
        return entry
    }

    @Test("Replies sit under the mail they answer; a reply whose mail is not here joins its subject")
    func tree() {
        let start = mail("a", "Sperrmüll im Hof", from: "Tom Beispiel <tom@example.org>", day: 1, answers: "")
        let one = mail("b", "Re: Sperrmüll im Hof", from: "Ida Muster <ida@example.org>", day: 3, answers: "a")
        let two = mail("c", "AW: Sperrmüll im Hof", from: "Lea Probe <lea@example.org>", day: 4, answers: "a")
        let onTwo = mail("d", "Re: AW: Sperrmüll im Hof", from: "Ida Muster <ida@example.org>", day: 5, answers: "c")
        // Answers a mail the matter does not have, and its reply link is not known yet.
        let stray = mail("e", "Re: Sperrmüll im Hof", from: "Max Test <max@example.org>", day: 2, answers: nil)
        let other = mail("f", "Heizung", from: "Tom Beispiel <tom@example.org>", day: 6, answers: "")

        let threads = MailThreads.build([two, other, onTwo, start, stray, one])
        #expect(threads.map(\.subject) == ["Heizung", "Sperrmüll im Hof"])
        let house = threads[1]
        #expect(house.count == 5)
        #expect(house.senders == ["Tom Beispiel", "Max Test", "Ida Muster", "Lea Probe"])
        #expect(house.rows.map(\.entry.messageID) == ["a", "e", "b", "c", "d"])
        #expect(house.rows.map(\.depth) == [0, 1, 1, 1, 2])
        #expect(house.rows.map(\.isLast) == [true, false, false, true, true])
        // Under the last reply to the first mail, no line of the level above goes on.
        #expect(house.rows[4].rails == [false])
    }

    @Test("A reply at the deepest indent that is answered is joined to its answer; a last one is not")
    func joined() {
        // A chain six deep, and a second reply to the first mail after it.
        let chain = ["a", "b", "c", "d", "e", "f"]
        var mails = chain.enumerated().map { index, id in
            mail(id, index == 0 ? "Ausklang" : "Re: Ausklang", from: "P\(index) <p\(index)@example.org>", day: index + 1, answers: index == 0 ? "" : chain[index - 1])
        }
        mails.append(mail("g", "Re: Ausklang", from: "Jasper <j@example.org>", day: 9, answers: "a"))
        let rows = MailThreads.build(mails)[0].rows
        #expect(rows.map(\.depth) == [0, 1, 2, 3, 4, 5, 1])
        // Shown four deep: "e" stands at the fourth indent and is answered by "f", which cannot step in.
        let four = MailThreads.joined(rows, deepest: 4)
        #expect(rows.filter { four.contains($0.id) }.map(\.entry.messageID) == ["e"])
        // Shown three deep, as on the iPhone: "d" and "e" both.
        let three = MailThreads.joined(rows, deepest: 3)
        #expect(rows.filter { three.contains($0.id) }.map(\.entry.messageID) == ["d", "e"])
        // The line of the first level goes on past the deep ones, down to the second reply.
        #expect(rows[5].rails.prefix(3) == [true, false, false])
    }

    @Test("Two mails answering each other are never a loop")
    func noLoop() {
        let a = mail("a", "x", from: "a@example.org", day: 1, answers: "b")
        let b = mail("b", "Re: x", from: "b@example.org", day: 2, answers: "a")
        let threads = MailThreads.build([a, b])
        #expect(threads.count == 1)
        #expect(threads[0].rows.map(\.entry.messageID) == ["a", "b"])
    }

    @Test("\"Re:\" and \"AW:\" are taken off the subject, its own words are kept as written")
    func subject() {
        #expect(MailThreads.clean("Re: AW: SperrMüll in der Mühle") == "SperrMüll in der Mühle")
        #expect(MailThreads.clean("Rechnung") == "Rechnung")
    }

    @Test("Which mail answers which is read from the headers only, one fetch per folder")
    func links() async throws {
        let first = "Message-ID: <a@example.org>\nSubject: x\n\nHallo"
        let reply = "Message-ID: <b@example.org>\nIn-Reply-To: <a@example.org>\nReferences: <a@example.org>\nSubject: Re: x\n\nJa"
        let box = FakeMailbox(gmail: false, folders: [MailFolder(name: "INBOX", attributes: [])],
                              content: ["INBOX": [.init(uid: 1, thread: nil, raw: first), .init(uid: 2, thread: nil, raw: reply)]])
        let links = try await MailFetch.replyLinks(of: [
            (pointer: "imap://mail.example.org/INBOX;UIDVALIDITY=7/;UID=1", messageID: "a@example.org"),
            (pointer: "imap://mail.example.org/INBOX;UIDVALIDITY=7/;UID=2", messageID: "b@example.org"),
            (pointer: "imap://mail.example.org/INBOX;UIDVALIDITY=7/;UID=9", messageID: "gone@example.org"),
        ], from: box)
        #expect(links == ["a@example.org": "", "b@example.org": "a@example.org"])
        #expect(await box.wholeFetches.isEmpty)
    }
}
