import EventKit
import Foundation

/// Calendar and Reminders, asked away from the screen. Every question to them is a call to the
/// calendar database that the asker waits for: asked on the main thread — by the sync for every
/// connected task and appointment, by every chip on a page — the iPhone stood still for up to half a
/// second while it scrolled. The worker has a store of its own; what it hands out are plain values,
/// and the events and reminders themselves never leave it.
public actor CalendarWorker: CalendarAsking {
    public static let shared = CalendarWorker()
    private lazy var store = EKEventStore()

    public init() {}

    private var readsEvents: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    private var readsReminders: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    /// Back to the front: what changed while Causabee was away is read anew.
    public func refresh() { store.refreshSourcesIfNecessary() }

    private func event(_ id: String) -> EKEvent? {
        guard readsEvents, !id.isEmpty else { return nil }
        return store.calendarItems(withExternalIdentifier: id).compactMap { $0 as? EKEvent }.first
    }

    private func reminder(_ id: String) -> EKReminder? {
        guard readsReminders, !id.isEmpty else { return nil }
        return store.calendarItems(withExternalIdentifier: id).compactMap { $0 as? EKReminder }.first
    }

    // MARK: For the sync

    /// A connected event or reminder as it is now.
    public struct Seen: Sendable, Equatable {
        /// As the mirror compares them: an event's what, day, time and place; a reminder's text, day, time and done.
        public var fields: [String]
        /// When a reminder was ticked.
        public var completedAt: Date?
        /// An event's start and end, and whether it fills whole days.
        public var start: Date?
        public var end: Date?
        public var isAllDay = false
        /// Made by Causabee — its notes say so: its length was Causabee's, not the owner's.
        public var madeByCausabee = false
    }

    /// The events and reminders these ids stand for; one that is gone is not in the answer.
    public func look(events: [String], reminders: [String]) -> (events: [String: Seen], reminders: [String: Seen]) {
        var foundEvents: [String: Seen] = [:], foundReminders: [String: Seen] = [:]
        for id in Set(events) {
            guard let event = event(id) else { continue }
            foundEvents[id] = Seen(fields: Mirror.fields(of: event), start: event.startDate, end: event.endDate,
                                   isAllDay: event.isAllDay, madeByCausabee: event.notes?.hasPrefix("Causabee · ") == true)
        }
        for id in Set(reminders) {
            guard let reminder = reminder(id) else { continue }
            foundReminders[id] = Seen(fields: Mirror.fields(of: reminder), completedAt: reminder.completionDate)
        }
        return (foundEvents, foundReminders)
    }

    /// What the sync writes out.
    public enum Write: Sendable, Equatable {
        /// A reminder's text, day, time and done, as the mirror has them.
        case reminder(id: String, fields: [String])
        /// Ticked here before this device first looked at its reminder.
        case completed(id: String)
        /// An event's what, day, time and place.
        case event(id: String, fields: [String])
        /// A deadline's what and day; its time and length stay the owner's.
        case deadline(id: String, what: String, day: String)
        /// An event Causabee made an hour long, given the end its appointment knows.
        case end(id: String, at: Date)
    }

    /// Each in turn; says for each whether Calendar or Reminders has it now. Events are saved
    /// together at the end, as Calendar wants them.
    public func write(_ writes: [Write]) -> [Bool] {
        var events: [String: EKEvent] = [:]
        func event(_ id: String) -> EKEvent? {
            if let known = events[id] { return known }
            let found = self.event(id)
            events[id] = found
            return found
        }
        var done: [Bool] = []
        var commit = false
        for write in writes {
            switch write {
            case .reminder(let id, let fields):
                guard let reminder = reminder(id) else { done.append(false); continue }
                reminder.title = fields[0]
                reminder.isCompleted = fields[3] == "done"
                reminder.dueDateComponents = fields[1].isEmpty ? nil : Calendars.start(day: fields[1], time: fields[2].isEmpty ? nil : fields[2]).map { date in
                    Calendar.current.dateComponents(fields[2].isEmpty ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute], from: date)
                }
                done.append((try? store.save(reminder, commit: true)) != nil)
            case .completed(let id):
                guard let reminder = reminder(id) else { done.append(false); continue }
                reminder.isCompleted = true
                done.append((try? store.save(reminder, commit: true)) != nil)
            case .event(let id, let fields):
                guard let event = event(id) else { done.append(false); continue }
                let saved = Mirror.write(fields, to: event, store: store)
                commit = commit || saved
                done.append(saved)
            case .deadline(let id, let what, let day):
                guard let event = event(id) else { done.append(false); continue }
                let saved = Mirror.writeDeadline(what: what, day: day, to: event, store: store)
                commit = commit || saved
                done.append(saved)
            case .end(let id, let at):
                guard let event = event(id) else { done.append(false); continue }
                event.endDate = at
                let saved = (try? store.save(event, span: .thisEvent, commit: false)) != nil
                commit = commit || saved
                done.append(saved)
            }
        }
        if commit { try? store.commit() }
        return done
    }

    // MARK: For the chips

    /// What a chip shows: connected and there, connected and gone, found there to connect, or
    /// nothing there yet to add.
    public enum ChipAnswer: Sendable, Equatable {
        case linked(String)
        case gone
        case found(id: String, title: String, list: String)
        case none
    }

    /// The chip beside an appointment, a deadline or a task. The reminders are the ones the page
    /// read already: a reminder is found among them, not asked for again.
    public func chip(event isEvent: Bool, linkedID: String?, day: String?, time: String?, title: String,
                     reminders: [Calendars.Reminder]) -> ChipAnswer {
        if let id = linkedID {
            if isEvent { return event(id).map { .linked($0.calendar?.title ?? "") } ?? .gone }
            if let known = reminders.first(where: { $0.id == id }) { return .linked(known.list + (known.isDone ? " · done" : "")) }
            return reminder(id).map { .linked($0.calendar?.title ?? "") } ?? .gone
        }
        if isEvent {
            guard let day, let event = findEvent(day: day, time: time, what: title) else { return .none }
            return .found(id: event.calendarItemExternalIdentifier, title: event.title ?? "", list: event.calendar?.title ?? "")
        }
        return Calendars.findReminder(title, in: reminders, ownLists: ownLists).map { .found(id: $0.id, title: $0.title, list: $0.list) } ?? .none
    }

    /// An event on that day about the same thing — see `Calendars.findEvent`.
    private func findEvent(day: String, time: String?, what: String) -> EKEvent? {
        guard readsEvents, let start = Calendars.date(of: day), let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        let alike = events.filter { Duplicates.alike($0.title ?? "", what) }
        guard let at = Calendars.start(day: day, time: time) else { return alike.first }
        return alike.min { abs($0.startDate.timeIntervalSince(at)) < abs($1.startDate.timeIntervalSince(at)) }
    }

    /// The lists Causabee adds to — see `Calendars.ownLists`.
    private var ownLists: Set<String> {
        var names: Set<String> = [Calendars.ownName]
        if let id = UserDefaults.standard.string(forKey: Calendars.listKey), !id.isEmpty, let chosen = store.calendar(withIdentifier: id) {
            names.insert(chosen.title)
        }
        return names
    }
}

/// What the sync asks Calendar and Reminders, and writes there: the worker — or, in a test, one
/// that only pretends to be them.
public protocol CalendarAsking: Actor {
    func look(events: [String], reminders: [String]) async -> (events: [String: CalendarWorker.Seen], reminders: [String: CalendarWorker.Seen])
    func write(_ writes: [CalendarWorker.Write]) async -> [Bool]
}
