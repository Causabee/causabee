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

    /// The name of what Causabee makes when the owner has not chosen one of their own.
    public static let ownName = "Causabee"

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

    /// An event on that day that is this appointment: one about the same thing. Being at the same
    /// time is not enough — a blocker the owner put there for the slot was taken for the meeting,
    /// offered to connect to, and the meeting itself never came into the calendar chosen for it.
    public func findEvent(day: String, time: String?, what: String) -> EKEvent? {
        guard canReadEvents, !isSealed, let start = Self.date(of: day), let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        let alike = events.filter { Duplicates.alike($0.title ?? "", what) }
        // Two of the same name on one day: the one nearest in time.
        guard let at = Self.start(day: day, time: time) else { return alike.first }
        return alike.min { abs($0.startDate.timeIntervalSince(at)) < abs($1.startDate.timeIntervalSince(at)) }
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

    /// The reminder a task already is. In Causabee's own list, or the one chosen for it, half the
    /// words are enough; in the owner's other lists only nearly the same words: "Online-Antrag
    /// durchführen" in "Anschlussfinanzierung" is not "Online Check-in bei easyJet durchführen".
    public static func findReminder(_ text: String, in reminders: [Reminder], ownLists: Set<String> = [ownName]) -> Reminder? {
        reminders.first { ownLists.contains($0.list) && Duplicates.alike($0.title, text) }
            ?? reminders.first { !ownLists.contains($0.list) && Duplicates.same($0.title, text) }
    }

    /// The names of the lists Causabee adds to: its own, and the one chosen in Settings.
    public var ownLists: Set<String> {
        var names: Set<String> = [Self.ownName]
        if let id = UserDefaults.standard.string(forKey: Self.listKey), !id.isEmpty, let chosen = store.calendar(withIdentifier: id) {
            names.insert(chosen.title)
        }
        return names
    }

    // MARK: Where new ones go

    public static let calendarKey = "calendar.events", listKey = "calendar.reminders"

    /// The calendar the owner chose, or "Causabee", made the first time it is needed — never one
    /// of the owner's own lists: a task in "Anschlussfinanzierung" is lost there.
    public func targetCalendar(for type: EKEntityType) throws -> EKCalendar {
        let key = type == .event ? Self.calendarKey : Self.listKey
        let calendars = store.calendars(for: type).filter(\.allowsContentModifications)
        if let id = UserDefaults.standard.string(forKey: key), let chosen = calendars.first(where: { $0.calendarIdentifier == id }) {
            return chosen
        }
        if let own = calendars.first(where: { $0.title == Self.ownName }) { return own }
        // Only an account that holds this kind already can take a new list of it: a calendar-only
        // account "does not support reminders". iCloud first, then where the standard one is, then
        // the others, each tried in turn.
        let standard = type == .event ? store.defaultCalendarForNewEvents : store.defaultCalendarForNewReminders()
        let usable = store.sources.filter { !$0.calendars(for: type).isEmpty }
        var order = usable.filter { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }
        if let home = standard?.source, !order.contains(where: { $0.sourceIdentifier == home.sourceIdentifier }) { order.append(home) }
        order += usable.filter { source in !order.contains { $0.sourceIdentifier == source.sourceIdentifier } }
        var failure: Error?
        for source in order {
            let calendar = EKCalendar(for: type, eventStore: store)
            calendar.title = Self.ownName
            calendar.source = source
            do {
                try store.saveCalendar(calendar, commit: true)
                return calendar
            } catch {
                failure = failure ?? error
            }
        }
        throw Failure.noOwnList(type == .event ? "Calendar" : "Reminders", reason: failure?.localizedDescription)
    }

    public enum Failure: LocalizedError {
        case noOwnList(String, reason: String?)
        public var errorDescription: String? {
            switch self {
            case .noOwnList(let app, let reason):
                "Causabee could not make its list “\(Self.ownName)” in \(app)\(reason.map { " (\($0))" } ?? ""). "
                    + "Make a list called “\(Self.ownName)” there, or choose a list in Settings → Calendar and Reminders."
            }
        }
        static let ownName = "Causabee"
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
        event.notes = "Causabee · \(matter)"
        event.calendar = try targetCalendar(for: .event)
        try store.save(event, span: .thisEvent, commit: true)
        return event.calendarItemExternalIdentifier
    }

    /// A new reminder for a task; returns the id to keep with it.
    public func addReminder(text: String, due: String?, time: String?, note: String?, matter: String) throws -> String {
        guard !isSealed else { throw CocoaError(.featureUnsupported) }
        let reminder = EKReminder(eventStore: store)
        reminder.title = text
        reminder.notes = ["Causabee · \(matter)", note].compactMap { $0 }.joined(separator: "\n")
        if let due, let date = Self.start(day: due, time: time) {
            var parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
            if time != nil { parts.hour = Calendar.current.component(.hour, from: date); parts.minute = Calendar.current.component(.minute, from: date) }
            reminder.dueDateComponents = parts
        }
        reminder.calendar = try targetCalendar(for: .reminder)
        try store.save(reminder, commit: true)
        return reminder.calendarItemExternalIdentifier
    }

    /// A task that is deleted takes its reminder with it. Says whether there was one to take: one
    /// the owner removed in Reminders already, or the demo's, is none.
    @discardableResult
    public func removeReminder(_ id: String?) -> Bool {
        guard let reminder = reminder(id) else { return false }
        return (try? store.remove(reminder, commit: true)) != nil
    }

    /// An appointment or a deadline that is deleted takes its entry in Calendar with it — of one
    /// that repeats, only this one.
    @discardableResult
    public func removeEvent(_ id: String?) -> Bool {
        guard let event = event(id) else { return false }
        return (try? store.remove(event, span: .thisEvent, commit: true)) != nil
    }
}
