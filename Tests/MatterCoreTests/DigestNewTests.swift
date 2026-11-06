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
