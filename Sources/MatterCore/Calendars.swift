import EventKit
import Foundation

/// The owner's calendars and reminders, as the Mac's Calendar and Reminders show them — iCloud,
/// Google, Exchange alike. Read to find what a matter's appointments and tasks already are there;
/// added to only when the owner clicks "Add" (into the calendar and list they chose), and kept in
/// step for what is connected by the Mirror.
@MainActor
public final class Calendars {
    public static let shared = Calendars()
    public let store = EKEventStore()

    /// The name of what Matterbee makes when the owner has not chosen one of their own.
    public static let ownName = "Matterbee"

    /// Set for the demo: its made-up matters neither find the owner's own events and reminders
    /// nor add to them.
    public var isSealed = false

    public var canReadEvents: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    public var canReadReminders: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }
    public var asked: Bool {
        EKEventStore.authorizationStatus(for: .event) != .notDetermined && EKEventStore.authorizationStatus(for: .reminder) != .notDetermined
    }

    /// Asks macOS once for both; the owner answers in its own window.
    public func requestAccess() async -> (events: Bool, reminders: Bool) {
        let events = (try? await store.requestFullAccessToEvents()) ?? false
        let reminders = (try? await store.requestFullAccessToReminders()) ?? false
        return (events, reminders)
    }

    // MARK: Finding

    static func date(of text: String) -> Date? { MatterStatus.date(of: text) }

    static func start(day: String, time: String?) -> Date? {
        guard let date = date(of: day) else { return nil }
        guard let time, time.count == 5, let hour = Int(time.prefix(2)), let minute = Int(time.suffix(2)) else { return date }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

    /// The event this id stands for, if it is still there.
    public func event(_ id: String?) -> EKEvent? {
        guard canReadEvents, !isSealed, let id, !id.isEmpty else { return nil }
        return store.calendarItems(withExternalIdentifier: id).compactMap { $0 as? EKEvent }.first
    }

    public func reminder(_ id: String?) -> EKReminder? {
        guard canReadReminders, !isSealed, let id, !id.isEmpty else { return nil }
        return store.calendarItems(withExternalIdentifier: id).compactMap { $0 as? EKReminder }.first
    }

    /// An event on that day that is this appointment: at about the same time, or about the same thing.
    public func findEvent(day: String, time: String?, what: String) -> EKEvent? {
        guard canReadEvents, !isSealed, let start = Self.date(of: day), let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        let at = Self.start(day: day, time: time)
        return events.first { event in
            let near = time != nil && at.map { abs(event.startDate.timeIntervalSince($0)) <= 3_600 } == true
            return Duplicates.alike(event.title ?? "", what) || (near && !event.isAllDay)
        }
    }

    /// A reminder as far as a matter's page needs it: plain values, safe to pass around.
    public struct Reminder: Sendable, Hashable {
        public var id: String
        public var title: String
        public var isDone: Bool
        public var list: String
    }

    /// Every reminder, open or done in the last three months, read once for a matter's page.
    public func allReminders() async -> [Reminder] {
        guard canReadReminders, !isSealed else { return [] }
        let open = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let since = Calendar.current.date(byAdding: .month, value: -3, to: Date())
        let done = store.predicateForCompletedReminders(withCompletionDateStarting: since, ending: nil, calendars: nil)
        let first = await fetch(open)
        return first + (await fetch(done))
    }

    private func fetch(_ predicate: NSPredicate) async -> [Reminder] {
        await withCheckedContinuation { continuation in
            // Reminders answers on a queue of its own, not the main thread: the answer is turned
            // into plain values right there, by a function tied to no thread.
            store.fetchReminders(matching: predicate) { @Sendable found in
                continuation.resume(returning: Calendars.plain(found))
            }
        }
    }

    nonisolated static func plain(_ found: [EKReminder]?) -> [Reminder] {
        (found ?? []).map {
            Reminder(id: $0.calendarItemExternalIdentifier, title: $0.title ?? "", isDone: $0.isCompleted, list: $0.calendar?.title ?? "")
        }
    }

    public static func findReminder(_ text: String, in reminders: [Reminder]) -> Reminder? {
        reminders.first { Duplicates.alike($0.title, text) }
    }

    // MARK: Where new ones go

    public static let calendarKey = "calendar.events", listKey = "calendar.reminders"

    /// The calendar the owner chose, or "Matterbee", made in iCloud the first time it is needed.
    public func targetCalendar(for type: EKEntityType) throws -> EKCalendar {
        let key = type == .event ? Self.calendarKey : Self.listKey
        let calendars = store.calendars(for: type).filter(\.allowsContentModifications)
        if let id = UserDefaults.standard.string(forKey: key), let chosen = calendars.first(where: { $0.calendarIdentifier == id }) {
            return chosen
        }
        if let own = calendars.first(where: { $0.title == Self.ownName }) { return own }
        let standard = type == .event ? store.defaultCalendarForNewEvents : store.defaultCalendarForNewReminders()
        // Only an account that holds this kind already can take a new list of it: a calendar-only
        // account "does not support reminders". iCloud first, then where the standard one is.
        let usable = store.sources.filter { !$0.calendars(for: type).isEmpty }
        let source = usable.first { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }
            ?? standard?.source ?? usable.first
        let calendar = EKCalendar(for: type, eventStore: store)
        calendar.title = Self.ownName
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            // Not possible there: the owner's standard list or calendar, rather than nothing.
            if let standard, standard.allowsContentModifications { return standard }
            throw error
        }
    }

    // MARK: Adding, on a click

    /// A new event for an appointment or a deadline; returns the id to keep with it.
    public func addEvent(what: String, day: String, time: String?, place: String?, matter: String) throws -> String {
        guard !isSealed else { throw CocoaError(.featureUnsupported) }
        guard let start = Self.start(day: day, time: time) else { throw CocoaError(.formatting) }
        let event = EKEvent(eventStore: store)
        event.title = what
        event.startDate = start
        event.isAllDay = time == nil
        event.endDate = time == nil ? start : start.addingTimeInterval(3_600)
        event.location = place
        event.notes = "Matterbee · \(matter)"
        event.calendar = try targetCalendar(for: .event)
        try store.save(event, span: .thisEvent, commit: true)
        return event.calendarItemExternalIdentifier
    }

    /// A new reminder for a task; returns the id to keep with it.
    public func addReminder(text: String, due: String?, time: String?, note: String?, matter: String) throws -> String {
        guard !isSealed else { throw CocoaError(.featureUnsupported) }
        let reminder = EKReminder(eventStore: store)
        reminder.title = text
        reminder.notes = ["Matterbee · \(matter)", note].compactMap { $0 }.joined(separator: "\n")
        if let due, let date = Self.start(day: due, time: time) {
            var parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
            if time != nil { parts.hour = Calendar.current.component(.hour, from: date); parts.minute = Calendar.current.component(.minute, from: date) }
            reminder.dueDateComponents = parts
        }
        reminder.calendar = try targetCalendar(for: .reminder)
        try store.save(reminder, commit: true)
        return reminder.calendarItemExternalIdentifier
    }
}
