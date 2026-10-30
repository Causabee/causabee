import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// Calendar and Reminders as the sync sees them through the worker — here only pretended: what it
/// was asked, and what was written.
actor PretendCalendar: CalendarAsking {
    var events: [String: CalendarWorker.Seen] = [:]
    var reminders: [String: CalendarWorker.Seen] = [:]
    var written: [CalendarWorker.Write] = []
    var asked: [String] = []
    var refusing = false
    /// Done while the sync waits for the answer — the owner editing meanwhile.
    var meanwhile: (@MainActor @Sendable () -> Void)?

    func set(event id: String, _ fields: [String]) { events[id] = CalendarWorker.Seen(fields: fields) }
    func set(reminder id: String, _ fields: [String], completedAt: Date? = nil) { reminders[id] = CalendarWorker.Seen(fields: fields, completedAt: completedAt) }
    func refuse(_ refusing: Bool) { self.refusing = refusing }
    func whileAsked(_ work: (@MainActor @Sendable () -> Void)?) { meanwhile = work }
    func forget() { written = []; asked = [] }

    func look(events ids: [String], reminders rids: [String]) async -> (events: [String: CalendarWorker.Seen], reminders: [String: CalendarWorker.Seen]) {
        asked += ids + rids
        if let meanwhile { await meanwhile() }
        return (events.filter { ids.contains($0.key) }, reminders.filter { rids.contains($0.key) })
    }

    func write(_ writes: [CalendarWorker.Write]) async -> [Bool] {
        written += writes
        guard !refusing else { return writes.map { _ in false } }
        for write in writes {
            switch write {
            case .reminder(let id, let fields): reminders[id]?.fields = fields
            case .completed(let id): reminders[id]?.fields[3] = "done"
            case .event(let id, let fields): events[id]?.fields = fields
            case .deadline(let id, let what, let day): events[id]?.fields[0] = what; events[id]?.fields[1] = day
            case .end(let id, let at): events[id]?.end = at
            }
        }
        return writes.map { _ in true }
    }
}

@Suite("The sync, with Calendar and Reminders asked away from the screen")
@MainActor
struct MirrorSyncTests {
    let container: ModelContainer
    let context: ModelContext
    let calendar = PretendCalendar()
    let stamps = Mirror.Stamps(defaults: nil)

    init() throws {
        container = try MatterSchema.container(at: nil)
        context = ModelContext(container)
    }

    func source() -> Source { Source(kind: .mail, pointer: "x", date: Date()) }

    func sync(onlyChangedHere: Bool = false) async -> Mirror.Result {
        await Mirror.reconcile(context, worker: calendar, calendars: Calendars(), reads: (true, true), stamps: stamps, onlyChangedHere: onlyChangedHere)
    }

    @Test("A task moved here goes to its reminder; ticked in Reminders, it comes back done")
    func bothWays() async throws {
        let todo = Todo(text: "Hotel in Lyon buchen", owner: .me, due: "2026-11-02", source: source(), origin: "x")
        todo.reminderID = "r1"
        context.insert(todo)
        await calendar.set(reminder: "r1", ["Hotel buchen", "2026-11-02", "", ""])
        // Just connected: each side as it is, nothing goes anywhere.
        #expect(await sync() == Mirror.Result())
        #expect(await calendar.written.isEmpty)

        todo.due = "2026-11-05"
        #expect(await sync().pushed == 1)
        #expect(await calendar.written == [.reminder(id: "r1", fields: ["Hotel buchen", "2026-11-05", "", ""])])

        let ticked = Date(timeIntervalSince1970: 1_800_000_000)
        await calendar.set(reminder: "r1", ["Hotel buchen", "2026-11-05", "", "done"], completedAt: ticked)
        await calendar.forget()
        #expect(await sync().pulled == 1)
        #expect(todo.isDone && todo.doneAt == ticked && todo.text == "Hotel in Lyon buchen")
        #expect(await calendar.written.isEmpty)
    }

    @Test("A write that does not get through is tried again next time; one that does, not")
    func refused() async throws {
        let todo = Todo(text: "Zahnarzt anrufen", owner: .me, due: "2026-11-02", source: source(), origin: "x")
        todo.reminderID = "r1"
        context.insert(todo)
        await calendar.set(reminder: "r1", ["Zahnarzt anrufen", "2026-11-02", "", ""])
        _ = await sync()
        todo.due = "2026-11-03"
        await calendar.refuse(true)
        #expect(await sync().pushed == 0)
        #expect(await sync().pushed == 0)
        #expect(await calendar.written.count == 2)
        await calendar.refuse(false)
        #expect(await sync().pushed == 1)
        await calendar.forget()
        #expect(await sync() == Mirror.Result())
        #expect(await calendar.written.isEmpty)
    }

    @Test("Two appointments on one event: the one Calendar shows is kept in step, and nothing is written, then or after")
    func twoOnOneEvent() async throws {
        let first = Appointment(what: "Causabee test session — ends at 11:45 am", day: "2026-10-30", time: "10:00", place: nil, source: source())
        let second = Appointment(what: "Test session", day: "2026-10-30", time: "10:15", place: nil, source: source())
        for appointment in [first, second] {
            appointment.calendarID = "e1"
            appointment.endTime = "11:45"
            context.insert(appointment)
        }
        await calendar.set(event: "e1", ["Test session", "2026-10-30", "10:15", ""])
        for _ in 0..<3 { #expect(await sync() == Mirror.Result()) }
        #expect(await calendar.written.isEmpty)
        #expect(first.what == "Causabee test session — ends at 11:45 am" && first.time == "10:00")
    }

    @Test("Only what changed here is asked about after a save here")
    func onlyChanged() async throws {
        let moved = Todo(text: "Steuer", owner: .me, due: "2026-11-02", source: source(), origin: "x")
        let still = Todo(text: "Arzt", owner: .me, due: "2026-11-02", source: source(), origin: "x")
        moved.reminderID = "r1"; still.reminderID = "r2"
        context.insert(moved); context.insert(still)
        await calendar.set(reminder: "r1", ["Steuer", "2026-11-02", "", ""])
        await calendar.set(reminder: "r2", ["Arzt", "2026-11-02", "", ""])
        _ = await sync()
        await calendar.forget()
        moved.due = "2026-11-04"
        #expect(await sync(onlyChangedHere: true).pushed == 1)
        #expect(await calendar.asked == ["r1"])
    }

    @Test("Changed here while Calendar is asked: left as it is, for the sync its save starts")
    func changedMeanwhile() async throws {
        let todo = Todo(text: "Vertrag lesen", owner: .me, due: "2026-11-02", source: source(), origin: "x")
        todo.reminderID = "r1"
        context.insert(todo)
        await calendar.set(reminder: "r1", ["Vertrag lesen", "2026-11-02", "", ""])
        _ = await sync()
        // Renamed in Reminders; moved here while the sync waits for Reminders' answer.
        await calendar.set(reminder: "r1", ["Mietvertrag lesen", "2026-11-02", "", ""])
        await calendar.whileAsked { todo.due = "2026-11-06" }
        #expect(await sync() == Mirror.Result())
        #expect(todo.text == "Vertrag lesen")
        await calendar.whileAsked(nil)
        let next = await sync()
        #expect(next.pulled == 1 && next.pushed == 1)
        #expect(todo.text == "Mietvertrag lesen" && todo.due == "2026-11-06")
        #expect(await calendar.reminders["r1"]?.fields == ["Mietvertrag lesen", "2026-11-06", "", ""])
    }

    @Test("Stopped while Calendar is asked — the store about to be another one: nothing is touched")
    func cancelled() async throws {
        let todo = Todo(text: "Vertrag lesen", owner: .me, due: "2026-11-02", source: source(), origin: "x")
        todo.reminderID = "r1"
        context.insert(todo)
        await calendar.set(reminder: "r1", ["Vertrag lesen", "2026-11-02", "", ""])
        _ = await sync()
        await calendar.set(reminder: "r1", ["Mietvertrag lesen", "2026-11-02", "", "done"])
        final class Holder: @unchecked Sendable { var task: Task<Mirror.Result, Never>? }
        let holder = Holder()
        await calendar.whileAsked { holder.task?.cancel() }
        let task = Task { await self.sync() }
        holder.task = task
        #expect(await task.value == Mirror.Result())
        #expect(todo.text == "Vertrag lesen" && !todo.isDone)
    }

    @Test("A deadline moved here moves its event; an event Causabee made an hour long gets its appointment's end")
    func deadlineAndEnd() async throws {
        let deadline = Deadline(what: "Abgabe Steuer", day: "2026-11-02", source: source())
        deadline.calendarID = "d1"
        let appointment = Appointment(what: "Workshop", day: "2026-11-03", time: "10:00", place: nil, source: source())
        appointment.calendarID = "e1"
        appointment.endTime = "12:30"
        context.insert(deadline); context.insert(appointment)
        await calendar.set(event: "d1", ["Abgabe Steuer", "2026-11-02", "", ""])
        let start = try #require(Calendars.start(day: "2026-11-03", time: "10:00"))
        await calendar.setHourLong(event: "e1", ["Workshop", "2026-11-03", "10:00", ""], start: start)
        _ = await sync()
        let end = try #require(Calendars.start(day: "2026-11-03", time: "12:30"))
        #expect(await calendar.written == [.end(id: "e1", at: end)])
        #expect(appointment.endTime == "12:30")
        await calendar.forget()
        deadline.day = "2026-11-04"
        #expect(await sync().pushed == 1)
        #expect(await calendar.written == [.deadline(id: "d1", what: "Abgabe Steuer", day: "2026-11-04")])
    }
}

extension PretendCalendar {
    func setHourLong(event id: String, _ fields: [String], start: Date) {
        events[id] = CalendarWorker.Seen(fields: fields, start: start, end: start.addingTimeInterval(3_600), madeByCausabee: true)
    }
}
