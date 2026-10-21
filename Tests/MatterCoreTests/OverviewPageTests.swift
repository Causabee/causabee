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
