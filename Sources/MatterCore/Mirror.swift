import EventKit
import Foundation
import SwiftData

/// Connected appointments, deadlines and tasks kept in step with the owner's Calendar and
/// Reminders, both ways, field by field. Each remembers what both sides were when they were last
/// in step; a field that changed on one side since is written to the other, and when it changed
/// on both, the Calendar or Reminders side wins — the owner acted there most recently. What was
/// already different when they were connected — a task worded one way here, another there —
/// stays as it is on each side. Nothing that is not connected is touched.
///
/// What both sides were is remembered on each device for itself (`Stamps`), not with the task in
/// iCloud: Reminders and Calendar reach each device on their own, at their own pace, and a memory
/// written by the iPhone — "the reminder is done" — met a Mac whose Reminders did not have that yet.
/// The Mac then took the reminder for changed back, and put its old state into the task.
@MainActor
public enum Mirror {
    /// What each connected thing looked like on both sides when this device last had them in step.
    @MainActor
    public final class Stamps {
        public static let device = Stamps(defaults: .standard)
        private let defaults: UserDefaults?
        private var held: [String: String]
        private static let key = "mirror.stamps"

        /// With no defaults, kept only as long as it lives: for a test.
        public init(defaults: UserDefaults?) {
            self.defaults = defaults
            held = defaults?.dictionary(forKey: Self.key) as? [String: String] ?? [:]
        }

        subscript(id: String) -> String? {
            get { held[id] }
            set {
                guard held[id] != newValue else { return }
                held[id] = newValue
                defaults?.set(held, forKey: Self.key)
            }
        }
    }

    static let fieldSeparator = "\u{1F}", sideSeparator = "\u{1E}"

    /// The fields of both sides after a sync, and which way anything went.
    public struct Merge: Equatable {
        public var local: [String]
        public var remote: [String]
        public var stamp: String
        public var pushed: Bool
        public var pulled: Bool
    }

    public static func merge(local: [String], remote: [String], stamp: String?) -> Merge {
        func stampOf(_ l: [String], _ r: [String]) -> String {
            l.joined(separator: fieldSeparator) + sideSeparator + r.joined(separator: fieldSeparator)
        }
        let sides = stamp?.components(separatedBy: sideSeparator)
        guard let sides, sides.count == 2 else {
            // Just connected: each side as it is; from now on what changes is followed.
            return Merge(local: local, remote: remote, stamp: stampOf(local, remote), pushed: false, pulled: false)
        }
        let lastLocal = sides[0].components(separatedBy: fieldSeparator), lastRemote = sides[1].components(separatedBy: fieldSeparator)
        guard lastLocal.count == local.count, lastRemote.count == remote.count else {
            return Merge(local: local, remote: remote, stamp: stampOf(local, remote), pushed: false, pulled: false)
        }
        var newLocal = local, newRemote = remote
        var pushed = false, pulled = false
        for index in local.indices {
            if remote[index] != lastRemote[index] {
                if newLocal[index] != remote[index] { newLocal[index] = remote[index]; pulled = true }
            } else if local[index] != lastLocal[index] {
                if newRemote[index] != local[index] { newRemote[index] = local[index]; pushed = true }
            }
        }
        return Merge(local: newLocal, remote: newRemote, stamp: stampOf(newLocal, newRemote), pushed: pushed, pulled: pulled)
    }

    public struct Result: Sendable, Equatable {
        public var pushed = 0
        public var pulled = 0
    }

    static func time(of date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Whether what this side holds is still what it was when both were last in step: then only
    /// the other side can have changed it, and nothing needs asking there unless it has changed.
    static func unchangedHere(_ local: [String], stamp: String?) -> Bool {
        guard let stamp, let mine = stamp.components(separatedBy: sideSeparator).first else { return false }
        return mine == local.joined(separator: fieldSeparator)
    }

    /// Everything connected, both ways. Saves the store when something came in.
    ///
    /// `onlyChangedHere`: Calendar and Reminders said nothing changed there — only this store was
    /// saved. Then only what changed here is looked up there: each lookup asks Calendar's database,
    /// and asking for every connected thing after every tick held the screen up.
    public static func reconcile(_ context: ModelContext, calendars: Calendars = .shared, stamps: Stamps = .device,
                                 onlyChangedHere: Bool = false) -> Result {
        var result = Result()
        if calendars.canReadReminders {
            let todos = (try? context.fetch(FetchDescriptor<Todo>(predicate: #Predicate { $0.reminderID != nil }))) ?? []
            let kept = oneEach(todos.compactMap { todo in todo.reminderID.map { (key: todo.persistentModelID, id: $0, local: fields(of: todo)) } },
                               stamp: { stamps["reminder:" + $0] }, remote: { calendars.reminder($0).map(fields(of:)) })
            for todo in todos where kept.contains(todo.persistentModelID) {
                guard let id = todo.reminderID else { continue }
                if onlyChangedHere, unchangedHere(fields(of: todo), stamp: stamps["reminder:" + id]) { continue }
                guard let reminder = calendars.reminder(id) else { continue }
                // Seen here for the first time and done on one side only: a reminder is connected while
                // its task is open, so one of them was ticked since — and then both are done. Without
                // this, a task ticked before this device had looked once left its reminder open for good.
                if stamps["reminder:" + id] == nil, todo.isDone != reminder.isCompleted {
                    if todo.isDone {
                        reminder.isCompleted = true
                        if (try? calendars.store.save(reminder, commit: true)) != nil { result.pushed += 1 }
                    } else {
                        todo.isDone = true
                        todo.doneAt = reminder.completionDate ?? Date()
                        result.pulled += 1
                    }
                }
                let merge = Self.merge(local: fields(of: todo), remote: fields(of: reminder), stamp: stamps["reminder:" + id])
                if merge.pulled {
                    let l = merge.local
                    if !l[0].isEmpty { todo.text = l[0] }
                    todo.due = l[1].isEmpty ? nil : l[1]
                    todo.dueTime = l[2].isEmpty ? nil : l[2]
                    let done = l[3] == "done"
                    if done != todo.isDone {
                        todo.isDone = done
                        todo.doneAt = done ? (reminder.completionDate ?? Date()) : nil
                        if !done { todo.doneSource = nil }
                    }
                    result.pulled += 1
                }
                if merge.pushed {
                    let r = merge.remote
                    reminder.title = r[0]
                    reminder.isCompleted = r[3] == "done"
                    reminder.dueDateComponents = r[1].isEmpty ? nil : Calendars.start(day: r[1], time: r[2].isEmpty ? nil : r[2]).map { date in
                        Calendar.current.dateComponents(r[2].isEmpty ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute], from: date)
                    }
                    // In step only once Reminders has it: remembered over a failed write, the old
                    // state there would count as the owner's newer one next time.
                    guard (try? calendars.store.save(reminder, commit: true)) != nil else { continue }
                    result.pushed += 1
                }
                stamps["reminder:" + id] = merge.stamp
            }
        }
        if calendars.canReadEvents {
            let appointments = (try? context.fetch(FetchDescriptor<Appointment>())) ?? []
            let deadlines = (try? context.fetch(FetchDescriptor<Deadline>())) ?? []
            for appointment in appointments {
                // Its end said only in its name, as the assistant once wrote it: kept as its end,
                // and the name without it — Calendar gets both below.
                if appointment.endTime == nil, appointment.what.contains(where: \.isNumber),
                   let end = Calendars.endClock(in: appointment.what, after: appointment.time) {
                    appointment.endTime = end
                    appointment.what = Calendars.withoutEnd(appointment.what)
                }
            }
            let kept = oneEach(appointments.compactMap { a in a.calendarID.map { (key: a.persistentModelID, id: $0, local: fields(of: a)) } }
                                   + deadlines.compactMap { d in d.calendarID.map { (key: d.persistentModelID, id: $0, local: [d.what, d.day]) } },
                               stamp: { stamps["event:" + $0] }, remote: { calendars.event($0).map(fields(of:)) })
            for appointment in appointments where kept.contains(appointment.persistentModelID) {
                guard let id = appointment.calendarID else { continue }
                if onlyChangedHere, unchangedHere(fields(of: appointment), stamp: stamps["event:" + id]) { continue }
                guard let event = calendars.event(id) else { continue }
                // An event Causabee made an hour long, as every one was, while the appointment knows
                // when it ends: given that end, before Calendar's end is taken as the owner's. One
                // whose length the owner has set is theirs.
                if event.notes?.hasPrefix("Causabee · ") == true, !event.isAllDay,
                   abs(event.endDate.timeIntervalSince(event.startDate) - 3_600) < 1,
                   let span = Calendars.span(what: appointment.what, day: appointment.day, time: appointment.time,
                                             endDay: appointment.endDay, endTime: appointment.endTime),
                   !span.allDay, abs(span.start.timeIntervalSince(event.startDate)) < 1, abs(span.end.timeIntervalSince(event.endDate)) > 1 {
                    event.endDate = span.end
                    if (try? calendars.store.save(event, span: .thisEvent, commit: false)) != nil { result.pushed += 1 }
                }
                let merge = Self.merge(local: fields(of: appointment), remote: fields(of: event), stamp: stamps["event:" + id])
                if merge.pulled {
                    let l = merge.local
                    appointment.what = l[0]; appointment.day = l[1]
                    appointment.time = l[2].isEmpty ? nil : l[2]; appointment.place = l[3].isEmpty ? nil : l[3]
                    result.pulled += 1
                }
                // The end is Calendar's to say: what the owner set there is kept here.
                let end = Self.end(of: event)
                if appointment.endDay != end.day { appointment.endDay = end.day }
                if appointment.endTime != end.time { appointment.endTime = end.time }
                // In step only once Calendar has it too: a stamp over a failed write would take the
                // old Calendar value for the owner's newer one next time, and put it back.
                let written = !merge.pushed || write(merge.remote, to: event, calendars: calendars)
                if merge.pushed, written { result.pushed += 1 }
                if written { stamps["event:" + id] = merge.stamp }
            }
            for deadline in deadlines where kept.contains(deadline.persistentModelID) {
                guard let id = deadline.calendarID else { continue }
                if onlyChangedHere, unchangedHere([deadline.what, deadline.day], stamp: stamps["event:" + id]) { continue }
                guard let event = calendars.event(id) else { continue }
                let theirs = fields(of: event)
                let merge = Self.merge(local: [deadline.what, deadline.day], remote: [theirs[0], theirs[1]], stamp: stamps["event:" + id])
                if merge.pulled { deadline.what = merge.local[0]; deadline.day = merge.local[1]; result.pulled += 1 }
                let written = !merge.pushed || writeDeadline(what: merge.remote[0], day: merge.remote[1], to: event, calendars: calendars)
                if merge.pushed, written { result.pushed += 1 }
                if written { stamps["event:" + id] = merge.stamp }
            }
        }
        if result.pushed > 0 { try? calendars.store.commit() }
        if context.hasChanges { try? context.save() }
        return result
    }

    static func fields(of event: EKEvent) -> [String] {
        [event.title ?? "", MatterStatus.day(event.startDate), event.isAllDay ? "" : time(of: event.startDate), event.location ?? ""]
    }

    static func fields(of appointment: Appointment) -> [String] {
        [appointment.what, appointment.day, appointment.time ?? "", appointment.place ?? ""]
    }

    static func fields(of todo: Todo) -> [String] {
        [todo.text, todo.due ?? "", todo.dueTime ?? "", todo.isDone ? "done" : ""]
    }

    static func fields(of reminder: EKReminder) -> [String] {
        let parts = reminder.dueDateComponents
        let due = parts.flatMap { Calendar.current.date(from: $0) }.map { MatterStatus.day($0) } ?? ""
        let dueTime = (parts?.hour).map { String(format: "%02d:%02d", $0, parts?.minute ?? 0) } ?? ""
        return [reminder.title ?? "", due, dueTime, reminder.isCompleted ? "done" : ""]
    }

    /// Several connected to one event or reminder — the same appointment in two matters: only one
    /// of them is kept in step with it. Each wrote its own into it and the next its own back, the
    /// sync never ended, and the iPhone stopped every two seconds. The one kept is the one that was
    /// in step last time, else the one Calendar or Reminders shows now, else the first; the others
    /// stay as they are. `remote` is asked only for one connected more than once.
    static func oneEach<Key: Hashable>(_ items: [(key: Key, id: String, local: [String])], stamp: (String) -> String?,
                                       remote: (String) -> [String]?) -> Set<Key> {
        var kept = Set<Key>()
        var sharing: [String: [(key: Key, id: String, local: [String])]] = [:]
        for item in items { sharing[item.id, default: []].append(item) }
        for item in items where sharing[item.id]?.count == 1 { kept.insert(item.key) }
        for (id, alike) in sharing where alike.count > 1 {
            let last = stamp(id)
            let theirs = alike.contains { unchangedHere($0.local, stamp: last) } ? nil : remote(id)
            let one = alike.first { unchangedHere($0.local, stamp: last) }
                ?? theirs.flatMap { theirs in alike.first { Array(theirs.prefix($0.local.count)) == $0.local } }
                ?? alike[0]
            kept.insert(one.key)
        }
        return kept
    }

    /// The last day of an event that runs over several, and the hour it ends — as an appointment keeps them.
    static func end(of event: EKEvent) -> (day: String?, time: String?) {
        let first = MatterStatus.day(event.startDate), last = MatterStatus.day(event.endDate)
        if event.isAllDay { return (last > first ? last : nil, nil) }
        return (last > first ? last : nil, time(of: event.endDate))
    }

    /// A deadline knows only what and which day: the time and place the owner may have given it in
    /// Calendar stay as they are, and a new day keeps the event's own time and length.
    private static func writeDeadline(what: String, day: String, to event: EKEvent, calendars: Calendars) -> Bool {
        event.title = what
        if MatterStatus.day(event.startDate) != day,
           let start = Calendars.start(day: day, time: event.isAllDay ? nil : time(of: event.startDate)) {
            let length = event.endDate.timeIntervalSince(event.startDate)
            event.startDate = start
            event.endDate = start.addingTimeInterval(length)
        }
        return (try? calendars.store.save(event, span: .thisEvent, commit: false)) != nil
    }

    private static func write(_ fields: [String], to event: EKEvent, calendars: Calendars) -> Bool {
        let time = fields[2].isEmpty ? nil : fields[2]
        guard let start = Calendars.start(day: fields[1], time: time) else { return false }
        let length = event.isAllDay ? 3_600 : max(event.endDate.timeIntervalSince(event.startDate), 900)
        // A stay over several days keeps its days when it moves.
        let days = event.isAllDay ? Calendar.current.dateComponents([.day], from: event.startDate, to: event.endDate).day ?? 0 : 0
        event.title = fields[0]
        event.isAllDay = time == nil
        event.startDate = start
        event.endDate = time == nil ? Calendar.current.date(byAdding: .day, value: max(days, 0), to: start) ?? start : start.addingTimeInterval(length)
        event.location = fields[3].isEmpty ? nil : fields[3]
        return (try? calendars.store.save(event, span: .thisEvent, commit: false)) != nil
    }
}
