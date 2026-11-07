import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// What is new on the Digest: what mail, files and Pro brought since the last "Seen" — not what the
/// owner added by hand, not what is done or put away; "Seen" clears it, and the news with it.
@Suite("New on the Digest")
@MainActor
struct DigestNewTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func mail(_ hoursAgo: Double) -> Source {
        Source(kind: .mail, pointer: "imap://x;UID=\(Int(hoursAgo))", messageID: "<\(Int(hoursAgo))@x>", date: now.addingTimeInterval(-hoursAgo * 3600))
    }

    private func matter() throws -> (Matter, ModelContext) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "move", name: "Move")
        context.insert(matter)
        return (matter, context)
    }

    @discardableResult
    private func task(_ text: String, hoursAgo: Double, in matter: Matter, _ context: ModelContext, source: Source? = nil) -> Todo {
        let todo = Todo(text: text, owner: .me, due: nil, source: source ?? mail(hoursAgo), origin: text)
        todo.createdAt = now.addingTimeInterval(-hoursAgo * 3600)
        context.insert(todo)
        todo.matter = matter
        return todo
    }

    @Test("With nothing seen yet, what came in the last three days is new; older is not")
    func firstLook() throws {
        let (matter, context) = try matter()
        task("Book the van", hoursAgo: 5, in: matter, context)
        task("Ask about boxes", hoursAgo: 24 * 10, in: matter, context)
        #expect(matter.newItems(now: now).map(\.id) .count == 1)
    }

    @Test("Added by hand, done or put away: not new")
    func notNew() throws {
        let (matter, context) = try matter()
        task("Mine", hoursAgo: 1, in: matter, context, source: Source(kind: .conversation, pointer: "you"))
        task("Done", hoursAgo: 1, in: matter, context).isDone = true
        task("Hidden", hoursAgo: 1, in: matter, context).isHidden = true
        let fact = task("A fact", hoursAgo: 1, in: matter, context)
        fact.isInfo = true
        let items = matter.newItems(now: now)
        #expect(items.count == 1)
        if case .fact(let todo) = items.first { #expect(todo.text == "A fact") } else { Issue.record("The fact is not new.") }
    }

    @Test("A date is new by its mail's day, and only while it is ahead")
    func dates() throws {
        let (matter, context) = try matter()
        let ahead = Appointment(what: "Movers", day: MatterStatus.day(now.addingTimeInterval(86400 * 5)), time: "08:00", place: nil, source: mail(2))
        let past = Appointment(what: "Long ago", day: "2020-01-01", time: nil, place: nil, source: mail(2))
        for item in [ahead, past] { context.insert(item); item.matter = matter }
        let items = matter.newItems(now: now)
        #expect(items.count == 1)
        if case .appointment(let date) = items.first { #expect(date.what == "Movers") } else { Issue.record("The date ahead is not new.") }
    }

    @Test("Seen clears what is new and the news; what comes after is new again")
    func seen() throws {
        let (matter, context) = try matter()
        task("Book the van", hoursAgo: 5, in: matter, context)
        var brief = Brief()
        brief.news = Brief.News(lines: ["The move is confirmed."], mails: 1, since: now)
        matter.shownBrief = brief
        matter.sawNew(at: now)
        #expect(matter.newItems(now: now).isEmpty)
        #expect(matter.shownBrief?.news?.seen == true)
        task("Get a parking permit", hoursAgo: -1, in: matter, context)
        #expect(matter.newItems(now: now.addingTimeInterval(7200)).count == 1)
        // Written again, the brief keeps when it was seen.
        let again = try #require(matter.shownBrief).rewritten(lines: [], proposals: [])
        #expect(again.newSeenAt == now)
    }
}

/// The overview's card says who, small, and what happened under it: the news, what is new, or
/// what the newest mail says.
@Suite("What happened, on the overview")
@MainActor
struct OverviewHappenedTests {
    @Test("What is new before who wrote; the news before both")
    func order() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "move", name: "Move")
        context.insert(matter)
        let mail = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<1@x>", date: Date())
        let entry = Entry(title: "Your move is confirmed", from: "Carry & Co <info@carry.example>", date: Date(), source: mail)
        entry.digest = "Two movers and a van from 8 to 12."
        context.insert(entry)
        entry.matter = matter
        let today = MatterStatus.day(Date())
        // Who wrote it on a line of its own; what it says, from its summary's first sentence.
        let plain = MatterSummary(matter, today: today)
        #expect(plain.who == "Carry & Co" && plain.what == "Two movers and a van from 8 to 12.")
        entry.digest = nil
        #expect(MatterSummary(matter, today: today).what == "Your move is confirmed")
        let todo = Todo(text: "Book a parking permit", owner: .me, due: nil, source: mail, origin: "p")
        context.insert(todo)
        todo.matter = matter
        let fresh = MatterSummary(matter, today: today)
        #expect(fresh.what == "New task: Book a parking permit" && fresh.newCount == 1)
        var brief = Brief()
        brief.news = Brief.News(lines: ["The move is confirmed."], mails: 1, since: Date())
        matter.shownBrief = brief
        #expect(MatterSummary(matter, today: today).what == "The move is confirmed.")
    }

    @Test("A subject without AW:, Fwd: and Chat:; a chat or a file says what it was")
    func plainWords() throws {
        #expect(MatterSummary.subject("AW: WG: Ihre Buchung") == "Ihre Buchung")
        #expect(MatterSummary.subject("Chat: Reha Mama") == "Reha Mama")
        #expect(MatterSummary.subject("Chat:") == "Chat:")
        #expect(MatterSummary.firstSentence("Two movers come. They bring a van.") == "Two movers come.")
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama", name: "Mama")
        context.insert(matter)
        let entry = Entry(title: "Chat: Reha Mama", from: "reha mama", date: Date(), source: Source(kind: .conversation, pointer: "c"))
        context.insert(entry)
        entry.matter = matter
        let summary = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(summary.who == "Chat" && summary.what == "Reha Mama")
    }
}

@Suite("What came, in a notification")
struct NewsCameTests {
    @Test("Mails are counted; a screenshot or a file makes it new info")
    func came() {
        #expect(Brief.News(lines: [], mails: 1, since: Date()).came == "1 new mail")
        #expect(Brief.News(lines: [], mails: 2, since: Date(), screenshots: 0, files: 0).came == "2 new mails")
        #expect(Brief.News(lines: [], mails: 0, since: Date(), screenshots: 1, files: 0).came == "New info")
        #expect(Brief.News(lines: [], mails: 1, since: Date(), screenshots: 0, files: 1).came == "New info")
    }
}

@Suite("Kept one by one")
@MainActor
struct KeptNewTests {
    @Test("✓ takes one off what is new and keeps it in the matter; the others stay new; Seen forgets the list")
    func keep() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "move", name: "Move")
        context.insert(matter)
        let mail = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<1@x>", date: Date())
        for text in ["Book the van", "Pack the boxes"] {
            let todo = Todo(text: text, owner: .me, due: nil, source: mail, origin: "<1@x>#" + text)
            context.insert(todo)
            todo.matter = matter
        }
        let first = try #require(matter.newItems().first)
        matter.keepNew(first)
        #expect(matter.newItems().count == 1)
        #expect(matter.openTodos.count == 2)
        matter.sawNew()
        #expect(matter.shownBrief?.newKept.isEmpty == true)
        #expect(matter.newItems().isEmpty)
    }
}
