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
        // A pleasantry is passed over; one with a number says something and stays.
        #expect(MatterSummary.firstSentence("Wir freuen uns sehr auf die zukünftige Zusammenarbeit mit Ihnen. Matera übernimmt die Verwaltung ab 1. Januar.")
                == "Matera übernimmt die Verwaltung ab 1. Januar.")
        #expect(MatterSummary.firstSentence("Vielen Dank für Ihre Zahlung von 120 €. Der Platz ist sicher.") == "Vielen Dank für Ihre Zahlung von 120 €.")
        #expect(MatterSummary.firstSentence("We look forward to working with you.") == nil)
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama", name: "Mama")
        context.insert(matter)
        let entry = Entry(title: "Chat: Reha Mama", from: "reha mama", date: Date(), source: Source(kind: .conversation, pointer: "c"))
        context.insert(entry)
        entry.matter = matter
        let summary = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(summary.who == "Chat" && summary.what == "Reha Mama")
    }

    @Test("A mail's card opens at the mail; a file's at the file, as the page shows it")
    func opensAt() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "doc", name: "Doc")
        context.insert(matter)
        let source = Source(kind: .document, pointer: "file:///Boka.pdf")
        let entry = Entry(title: "Boka tid för", from: "dokument", date: Date(), source: source)
        context.insert(entry)
        entry.matter = matter
        let file = Document(name: "Boka.pdf", contentType: "application/pdf", byteCount: 10, source: source)
        context.insert(file)
        file.matter = matter
        let summary = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(summary.who == "File" && summary.latest?.entry == file.persistentModelID)
        let mail = Entry(title: "Termin", from: "Praxis <p@example.org>", date: Date().addingTimeInterval(60),
                         source: Source(kind: .mail, pointer: "imap://x;UID=2", messageID: "<2@x>"))
        context.insert(mail)
        mail.matter = matter
        #expect(MatterSummary(matter, today: MatterStatus.day(Date())).latest?.entry == mail.persistentModelID)
    }

    @Test("A note written after the last mail is the latest: said as the owner's, and opened at")
    func noteIsLatest() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "dev", name: "Dev")
        context.insert(matter)
        let mail = Entry(title: "Double files", from: "Me <me@example.org>", date: Date().addingTimeInterval(-86_400),
                         source: Source(kind: .mail, pointer: "imap://x;UID=3", messageID: "<3@x>"))
        context.insert(mail)
        mail.matter = matter
        let note = MatterNote(text: "Screenshots show the app, not the content.", createdAt: Date())
        context.insert(note)
        note.matter = matter
        let summary = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(summary.who == "Your note" && summary.what == "Screenshots show the app, not the content.")
        #expect(summary.latest?.entry == note.persistentModelID && !summary.tellsNew)
        // The journal finds its line, to go to it.
        let lines = Journal.lines(items: [], notes: [note])
        #expect(Journal.line(of: note.persistentModelID, in: lines, attached: [:]) != nil)
    }

    @Test("A task added or done by hand is the latest as well: the newest thing, whoever made it")
    func taskIsLatest() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "car", name: "Car")
        context.insert(matter)
        let mail = Source(kind: .mail, pointer: "imap://x;UID=4", messageID: "<4@x>", date: Date().addingTimeInterval(-3_600))
        let entry = Entry(title: "Estimate", from: "Garage <g@example.org>", date: mail.date, source: mail)
        context.insert(entry)
        entry.matter = matter
        // From the mail: the mail's date, so the mail stays the latest.
        let fromMail = Todo(text: "Send the estimate", owner: .me, due: nil, source: mail, origin: "m")
        context.insert(fromMail)
        fromMail.matter = matter
        #expect(MatterSummary(matter, today: MatterStatus.day(Date())).latest?.made == nil)
        // The task from the mail is new until the matter is opened: then the owner's own step is told.
        matter.sawNew(at: Date().addingTimeInterval(-1))
        let mine = Todo(text: "Call the insurer", owner: .me, due: nil, source: Source(kind: .conversation, pointer: ""), origin: "h")
        mine.createdAt = Date()
        context.insert(mine)
        mine.matter = matter
        let added = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(added.who == "Task added" && added.what == "Call the insurer" && added.latest?.entry == mine.persistentModelID)
        fromMail.isDone = true
        fromMail.doneAt = Date().addingTimeInterval(5)
        let done = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(done.who == "Done" && done.what == "Send the estimate")
    }

    @Test("Something new not yet seen is what the card says, under NEW, before the owner's own step; opened, it is not new")
    func newBeforeOwnStep() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "car2", name: "Car")
        context.insert(matter)
        let mail = Source(kind: .mail, pointer: "imap://x;UID=5", messageID: "<5@x>", date: Date().addingTimeInterval(-3_600))
        let entry = Entry(title: "Estimate", from: "Garage <g@example.org>", date: mail.date, source: mail)
        context.insert(entry)
        entry.matter = matter
        let fromMail = Todo(text: "Send the estimate", owner: .me, due: nil, source: mail, origin: "m")
        context.insert(fromMail)
        fromMail.matter = matter
        let mine = Todo(text: "Call the insurer", owner: .me, due: nil, source: Source(kind: .conversation, pointer: ""), origin: "h")
        mine.createdAt = Date()
        context.insert(mine)
        mine.matter = matter
        let unseen = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(unseen.isNew && unseen.tellsNew && unseen.who == nil && unseen.what?.contains("Send the estimate") == true)
        #expect(matter.openedNew())
        let seen = MatterSummary(matter, today: MatterStatus.day(Date()))
        #expect(!seen.isNew && !seen.tellsNew && seen.who == "Task added" && seen.what == "Call the insurer")
        #expect(!matter.openedNew())
        // Looked at, not handled: still on the card, as a read mail stays in the inbox.
        #expect(matter.newItems().count == 1 && matter.unopenedNew().isEmpty)
    }

    @Test("Opened news loses NEW and stays until Seen; news written after is NEW again")
    func openedNewsStays() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "n", name: "N")
        context.insert(matter)
        var brief = Brief()
        brief.news = Brief.News(lines: ["The landlord agreed."], mails: 1, since: Date())
        matter.shownBrief = brief
        #expect(matter.saysNew() && matter.openedNew())
        #expect(!matter.saysNew() && matter.shownBrief?.news?.seen == false)
        #expect(MatterSummary(matter, today: MatterStatus.day(Date())).isNew == false)
        let fresh = matter.shownBrief!.rewritten(lines: [], proposals: [], news: Brief.News(lines: ["He wants the keys."], mails: 1, since: Date()))
        matter.shownBrief = fresh
        #expect(matter.saysNew())
        matter.sawNew()
        #expect(!matter.saysNew() && matter.shownBrief?.news?.seen == true && matter.newItems().isEmpty)
    }

    @Test("A mail written last week and filed now is the latest, on the day it was filed")
    func filedLate() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "hv", name: "HV")
        context.insert(matter)
        let mine = Todo(text: "Check the handover", owner: .me, due: nil, source: Source(kind: .conversation, pointer: ""), origin: "h")
        mine.createdAt = Date().addingTimeInterval(-86_400)
        context.insert(mine)
        mine.matter = matter
        let mail = Source(kind: .mail, pointer: "imap://x;UID=9", messageID: "<9@x>", date: Date().addingTimeInterval(-7 * 86_400))
        let entry = Entry(title: "Minutes", from: "Conny <c@example.org>", date: mail.date, source: mail)
        context.insert(entry)
        entry.matter = matter
        #expect(MatterSummary(matter, today: MatterStatus.day(Date())).who == "Task added")
        context.insert(SortedMail(messageID: "<9@x>", device: "phone"))
        try context.save()
        let page = OverviewPage([matter])
        let summary = try #require(page.recent.first)
        #expect(summary.who == "Conny" && summary.latest?.entry == entry.persistentModelID)
        #expect(Calendar.current.isDateInToday(summary.latest?.date ?? .distantPast))
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

@Suite("The bee's proposals")
struct ProposalMailTests {
    @Test("Done only when a mail says so; the ids it cites are not shown")
    func backedBySource() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let entry = Entry(title: "Termin", from: "MD <md@example.org>", date: Date(), source: Source(kind: .mail, pointer: "m"))
        let todo = Todo(text: "Termin vereinbaren lassen", owner: .other, due: nil, source: Source(kind: .mail, pointer: "m"), origin: "t")
        context.insert(entry); context.insert(todo)
        let refs: [String: FactRef] = ["T10": .todo(todo.persistentModelID), "M3": .entry(entry.persistentModelID)]
        func card(_ cites: [String]) -> AssistantPrompt.Reply.Card {
            AssistantPrompt.Reply.Card(kind: .markDone, todo: "T10", text: "", owner: "me", due: nil, reason: "T10 deckt es ab", cites: cites)
        }
        #expect(!Brief.Proposal.backedBySource(card(["T10"]), refs: refs))
        #expect(Brief.Proposal.backedBySource(card(["M3"]), refs: refs))
        #expect(Brief.Proposal.readable("T10 deckt die Terminvereinbarung ab (M3).") == "deckt die Terminvereinbarung ab.")
    }

    @Test("A fact the bee writes again in other words is not new: it rests on what came on its day")
    func rewordedFactIsNotNew() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "f", name: "F")
        context.insert(matter)
        let old = Source(kind: .screenshot, pointer: "shot-1", date: Date().addingTimeInterval(-13 * 86_400))
        matter.putFacts([GoodToKnowFact(text: "The spare key is with Mrs. Adler.", sources: [old])], in: context)
        matter.sawNew()
        // Next morning the bee says it in other words: rebuilt, but not new.
        matter.putFacts([GoodToKnowFact(text: "Mrs. Adler next door has the spare key.", sources: [old])], in: context)
        #expect(matter.newItems().isEmpty && !matter.saysNew())
        // A fact from something that came today is new — whatever it came as.
        let today = Source(kind: .photo, pointer: "photo-2", date: Date())
        matter.putFacts([GoodToKnowFact(text: "The insurer pays up to 3,000 euros.", sources: [today])], in: context)
        #expect(matter.newItems().count == 1 && matter.saysNew())
    }

    @Test("A file that came in by itself counts for the brief's news, like a mail")
    func fileCountsAsCameIn() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "d", name: "D")
        context.insert(matter)
        var brief = Brief()
        brief.writtenAt = Date().addingTimeInterval(-3600)
        matter.shownBrief = brief
        let file = Document(name: "Offer.pdf", contentType: "application/pdf", byteCount: 1, source: Source(kind: .document, pointer: "Offer.pdf", date: Date()))
        context.insert(file)
        file.matter = matter
        #expect(matter.filesSinceBrief.count == 1)
    }
}
