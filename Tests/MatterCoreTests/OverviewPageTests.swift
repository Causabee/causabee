import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("The prepared overview: the same as working it out live, and fast with many matters")
@MainActor
struct OverviewPageTests {
    /// A store larger than the owner's: 50 matters, 100 mails, 12 tasks, 4 appointments and 2
    /// deadlines each — some late, some quiet, some closed.
    static func bigStore() throws -> (ModelContext, [Matter]) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let now = Date()
        func day(_ offset: Int) -> String { MatterStatus.day(now.addingTimeInterval(Double(offset) * 86_400)) }
        var matters: [Matter] = []
        for m in 0..<50 {
            let matter = Matter(key: "m\(m)", name: "Matter \(m)")
            context.insert(matter)
            if m % 10 == 0 { matter.closedAt = now.addingTimeInterval(-Double(m) * 3600) }
            if m % 17 == 1 { matter.pinnedAt = now.addingTimeInterval(Double(m)) }
            for e in 0..<100 {
                let source = Source(kind: .mail, pointer: "imap://x/INBOX;UIDVALIDITY=1/;UID=\(m * 1000 + e)", messageID: "<\(m)-\(e)@x>",
                                    date: now.addingTimeInterval(-Double(e) * 86_400 + Double(m)))
                let entry = Entry(title: "Mail \(e)", from: "a\(e)@example.com", date: source.date, source: source)
                entry.matter = matter
                context.insert(entry)
            }
            // Every fifth matter is quiet: nothing open, no day ahead.
            guard m % 5 != 4 else { continue }
            let source = Source(kind: .mail, pointer: "p", messageID: "<\(m)-0@x>", date: now)
            for t in 0..<12 {
                let todo = Todo(text: "Task \(t) of \(m)", owner: [.me, .we, .other][t % 3], due: day(t - 3 - (m % 4)), source: source, origin: "\(m)#\(t)")
                if t % 4 == 3 { todo.isDone = true }
                todo.matter = matter
                context.insert(todo)
            }
            for a in 0..<4 {
                let appointment = Appointment(what: "Visit \(a)", day: day(a * 2), time: "1\(a):00", place: nil, source: source)
                appointment.matter = matter
                context.insert(appointment)
            }
            for d in 0..<2 {
                let deadline = Deadline(what: "Deadline \(d)", day: day(d * 5 + 1), source: source)
                deadline.matter = matter
                context.insert(deadline)
            }
            matters.append(matter)
        }
        try context.save()
        return (context, (try? context.fetch(FetchDescriptor<Matter>())) ?? [])
    }

    /// What the screens work out live today: going on, late ones first, then by the next day.
    static func liveActive(_ matters: [Matter]) -> [String] {
        matters.compactMap { matter -> (matter: Matter, late: Bool, next: String)? in
            guard !matter.isClosed else { return nil }
            let status = MatterStatus(matter), next = status.next
            guard !matter.openTodos.isEmpty || next != nil else { return nil }
            return (matter, !status.overdue.isEmpty, next?.day ?? "9999")
        }
        .sorted { a, b in
            if a.late != b.late { return a.late }
            if a.next != b.next { return a.next < b.next }
            return a.matter.name.localizedStandardCompare(b.matter.name) == .orderedAscending
        }
        .map(\.matter.name)
    }

    @Test("The prepared page has what the live work out has: the matters going on and their order, each one's counts, the week")
    func sameAsLive() throws {
        let (_, matters) = try Self.bigStore()
        let page = OverviewPage(matters)
        #expect(page.active.map(\.name) == Self.liveActive(matters))
        for matter in matters {
            let status = MatterStatus(matter)
            let summary = try #require(page[matter.persistentModelID])
            #expect(summary.openCount == matter.openTodos.count)
            #expect(summary.mine == status.open(.me).count)
            #expect(summary.overdue.count == status.overdue.count)
            #expect(summary.next?.day == status.next?.day)
            #expect(summary.lastDate == status.lastDate)
            #expect(summary.newMailsSinceClosed == status.mailsSinceClosed.count)
        }
        for day in Week.days() {
            #expect(page.things(on: day).map(\.what) == Week.things(on: day, in: matters).map(\.what))
        }
        #expect(page.ordered.count == matters.count)
        #expect(page.pinned.map(\.name) == Pins.pinned(matters).map(\.name))
    }

    @Test("Preparing the overview of 50 matters and 5,000 mails stays within its budget; asked again unchanged, it is not prepared again")
    func budget() throws {
        let (_, matters) = try Self.bigStore()
        let clock = ContinuousClock()
        // Once to warm the store's faults, as the screen has them in memory.
        _ = OverviewPage(matters)
        let took = clock.measure { _ = OverviewPage(matters) }
        #expect(took < .milliseconds(250), "Preparing the overview took \(took)")
        let pages = OverviewPages()
        _ = pages.page(for: matters, version: 1)
        let again = clock.measure { for _ in 0..<1000 { _ = pages.page(for: matters, version: 1) } }
        #expect(again < .milliseconds(50), "Asking 1,000 times for the same page took \(again)")
    }

    @Test("Mail after closing shows on the overview until it is ignored, and the next mail shows alone; the matter still counts them all")
    func ignoredMailOfAClosedMatter() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "flat", name: "Flat")
        context.insert(matter)
        let now = Date()
        func mail(_ id: String, daysAgo: Double) {
            let date = now.addingTimeInterval(-daysAgo * 86_400)
            let entry = Entry(title: id, from: "a@example.com", date: date, source: Source(kind: .mail, pointer: id, messageID: id, date: date))
            context.insert(entry)
            entry.matter = matter
        }
        mail("<before>", daysAgo: 9)
        matter.close(markingOpenDone: false, at: now.addingTimeInterval(-8 * 86_400))
        mail("<one>", daysAgo: 3)
        mail("<two>", daysAgo: 2)
        let today = MatterStatus.day(now)
        let before = MatterSummary(matter, today: today)
        #expect(before.newMailsSinceClosed == 2)
        #expect(before.mailsToShowSinceClosed == 2)

        matter.ignoredMailUntil = before.lastDate
        #expect(MatterSummary(matter, today: today).newMailsSinceClosed == 2)
        #expect(MatterSummary(matter, today: today).mailsToShowSinceClosed == 0)

        mail("<three>", daysAgo: 1)
        #expect(MatterSummary(matter, today: today).newMailsSinceClosed == 3)
        #expect(MatterSummary(matter, today: today).mailsToShowSinceClosed == 1)

        matter.reopen()
        #expect(MatterSummary(matter, today: today).mailsToShowSinceClosed == 0)
    }

    @Test("A matter's last day says the mails and files that came on it: not a scan as a mail, not another day's file, not a hidden one or a small image")
    func cameOnTheLastDay() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "flat", name: "Flat")
        context.insert(matter)
        let now = Date()
        func entry(_ id: String, _ kind: Source.Kind, _ date: Date) {
            let source = Source(kind: kind, pointer: id, messageID: id, date: date)
            let entry = Entry(title: id, from: "a@example.com", date: date, source: source)
            context.insert(entry)
            entry.matter = matter
        }
        func file(_ id: String, _ type: String = "application/pdf", bytes: Int = 90_000, hidden: Bool = false) {
            let document = Document(name: id + ".pdf", contentType: type, byteCount: bytes, source: Source(kind: .mail, pointer: id, messageID: id))
            document.messageID = id
            document.isHidden = hidden
            context.insert(document)
            document.matter = matter
        }
        entry("<old>", .mail, now.addingTimeInterval(-3 * 86_400))
        entry("<a>", .mail, now.addingTimeInterval(-2))
        entry("<b>", .mail, now.addingTimeInterval(-1))
        entry("<scan>", .document, now)
        file("<old>")
        file("<a>")
        file("<a>", hidden: true)
        file("<b>", "image/png", bytes: 900)
        file("<scan>")
        let latest = try #require(MatterSummary(matter, today: MatterStatus.day(now)).latest)
        #expect(latest.mails == 2)
        #expect(latest.files == 2)
    }

    @Test("After a change with no new mail — a task ticked — the overview is prepared again without reading every mail's date, and a new mail still counts")
    func againAfterAChange() throws {
        let (context, matters) = try Self.bigStore()
        let clock = ContinuousClock()
        let pages = OverviewPages()
        _ = pages.page(for: matters, version: 1)
        let first = clock.measure { _ = OverviewPage(matters) }
        let todo = try #require(matters.first { !($0.todos ?? []).isEmpty }?.todos?.first)
        todo.isDone.toggle()
        let again = clock.measure { _ = pages.page(for: matters, version: 2) }
        print("Prepared again after a change: \(again), the first time \(first)")
        #expect(again < .milliseconds(120), "Preparing again after a change took \(again)")
        // A new mail, a day ahead of all: the matter's newest date follows.
        let matter = matters[0]
        let source = Source(kind: .mail, pointer: "p", messageID: "<new@x>", date: Date().addingTimeInterval(86_400))
        let entry = Entry(title: "New", from: "a@example.com", date: source.date, source: source)
        context.insert(entry)
        entry.matter = matter
        #expect(pages.page(for: matters, version: 3)[matter.persistentModelID]?.lastDate == source.date)
    }
}

extension OverviewPageTests {
    @Test("Measured: one drawing of the Mac's overview, live as today, against prepared")
    func liveAgainstPrepared() throws {
        let (_, matters) = try Self.bigStore()
        let clock = ContinuousClock()
        _ = OverviewPage(matters)
        // As the Mac's overview draws today: the matters going on three times, the week nine times,
        // a status per row and per sidebar row, the overdue list twice.
        let live = clock.measure {
            for _ in 0..<3 { _ = Self.liveActive(matters) }
            for day in Week.days() { _ = Week.things(on: day, in: matters) }
            _ = Week.things(on: Week.days()[0], in: matters); _ = Week.things(on: Week.days()[0], in: matters)
            for _ in 0..<2 { _ = matters.filter { !$0.isClosed }.flatMap { MatterStatus($0).overdue } }
            for matter in matters {
                let status = MatterStatus(matter)
                _ = (matter.openTodos.count, status.next, status.overdue.isEmpty, status.overdue.count, status.lastDate, status.mailsSinceClosed.count)
            }
        }
        let prepared = clock.measure {
            let page = OverviewPage(matters)
            for day in Week.days() { _ = page.things(on: day) }
            _ = page.overdue
        }
        print("OVERVIEW-MEASURE live \(live) prepared \(prepared) cached-redraw \(clock.measure { _ = OverviewPages.shared.page(for: matters, version: 7) })")
        #expect(prepared < live)
    }
}

/// Latest updates says what happened: a fact said again, or a task written down again when the
/// brief is reworded, is nothing new (9 November: "Bewerbung Shine" on top with nothing come in).
@Suite("Latest updates: only what happened")
@MainActor
struct LatestHappenedTests {
    func world() throws -> (ModelContext, Matter, Source) {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "shine", name: "Bewerbung Shine")
        context.insert(matter)
        let lastWeek = Date().addingTimeInterval(-7 * 86_400)
        let source = Source(kind: .mail, pointer: "imap://x", messageID: "offer@shine", date: lastWeek)
        let entry = Entry(title: "Ihr Angebot", from: "Pierrick <p@shine.example>", date: lastWeek, source: source)
        entry.matter = matter
        context.insert(entry)
        let record = SortedMail(messageID: "offer@shine", device: "test")
        record.sortedAt = lastWeek
        context.insert(record)
        try context.save()
        return (context, matter, source)
    }

    @Test("A fact put again today does not make the matter the latest")
    func factAgain() throws {
        let (context, matter, source) = try world()
        matter.putFacts([GoodToKnowFact(text: "Das Angebot enthält einen Essenszuschuss.", sources: [source])], in: context)
        let latest = try #require(MatterSummary(matter, today: MatterStatus.day(Date())).latest)
        #expect(latest.made == nil, "A fact said again stands as \(String(describing: latest.made))")
        #expect(Calendar.current.isDateInToday(latest.date) == false)
    }

    @Test("A task from a mail of last week, written down today, happened last week")
    func taskByArrival() throws {
        let (context, matter, source) = try world()
        let todo = Todo(text: "Bei Pierrick nachfragen", owner: .me, due: nil, source: source, origin: "offer#1")
        context.insert(todo); todo.matter = matter
        try context.save()
        let latest = try #require(MatterSummary(matter, today: MatterStatus.day(Date())).latest)
        #expect(Calendar.current.isDateInToday(latest.date) == false)
    }

    @Test("A task the owner adds today is today's")
    func ownTaskToday() throws {
        let (context, matter, _) = try world()
        let own = Source(kind: .conversation, pointer: "", messageID: "chat-1", date: Date())
        let todo = Todo(text: "Gehalt verhandeln", owner: .me, due: nil, source: own, origin: "chat#1")
        context.insert(todo); todo.matter = matter
        try context.save()
        let latest = try #require(MatterSummary(matter, today: MatterStatus.day(Date())).latest)
        #expect(latest.made == .taskAdded && Calendar.current.isDateInToday(latest.date))
    }
}
