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

    nonisolated static func time(of date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Whether what this side holds is still what it was when both were last in step: then only
    /// the other side can have changed it, and nothing needs asking there unless it has changed.
    static func unchangedHere(_ local: [String], stamp: String?) -> Bool {
        guard let stamp, let mine = stamp.components(separatedBy: sideSeparator).first else { return false }
        return mine == local.joined(separator: fieldSeparator)
    }

    /// Everything connected, both ways. Calendar and Reminders are asked and written by the
    /// worker, away from the screen: here only the store is read and changed. Does not save — the
    /// caller saves, and so knows that save for the sync's own.
    ///
    /// `onlyChangedHere`: Calendar and Reminders said nothing changed there — only this store was
    /// saved. Then only what changed here is looked up there.
    ///
    /// Cancelled while the worker answers, it stops there and touches nothing more: the store may
    /// be another one by then. One changed here meanwhile is left as it is, for the sync its save starts.
    public static func reconcile(_ context: ModelContext, worker: any CalendarAsking = CalendarWorker.shared, calendars: Calendars = .shared,
                                 reads: (events: Bool, reminders: Bool)? = nil, stamps: Stamps = .device,
                                 onlyChangedHere: Bool = false) async -> Result {
        var result = Result()
        guard !calendars.isSealed else { return result }
        let reads = reads ?? (calendars.canReadEvents, calendars.canReadReminders)
        let todos = reads.reminders ? (try? context.fetch(FetchDescriptor<Todo>(predicate: #Predicate { $0.reminderID != nil }))) ?? [] : []
        let appointments = reads.events ? (try? context.fetch(FetchDescriptor<Appointment>())) ?? [] : []
        let deadlines = reads.events ? (try? context.fetch(FetchDescriptor<Deadline>())) ?? [] : []
        for appointment in appointments {
            // Its end said only in its name, as the assistant once wrote it: kept as its end,
            // and the name without it — Calendar gets both below.
            if appointment.endTime == nil, appointment.what.contains(where: \.isNumber),
               let end = Calendars.endClock(in: appointment.what, after: appointment.time) {
                appointment.endTime = end
                appointment.what = Calendars.withoutEnd(appointment.what)
            }
        }
        // What each held when Calendar and Reminders were asked.
        var asked: [PersistentIdentifier: [String]] = [:]
        for todo in todos { asked[todo.persistentModelID] = fields(of: todo) }
        for appointment in appointments { asked[appointment.persistentModelID] = fields(of: appointment) }
        for deadline in deadlines { asked[deadline.persistentModelID] = fields(of: deadline) }
        func still(_ model: some PersistentModel, _ now: @autoclosure () -> [String]) -> Bool {
            !model.isDeleted && model.modelContext != nil && asked[model.persistentModelID] == now()
        }
        func connected(_ prefix: String, _ items: [(id: String, local: [String])]) -> [String] {
            items.filter { !onlyChangedHere || !unchangedHere($0.local, stamp: stamps[prefix + $0.id]) }.map(\.id)
        }
        let reminderIDs = connected("reminder:", todos.compactMap { todo in todo.reminderID.map { ($0, fields(of: todo)) } })
        let eventIDs = connected("event:", appointments.compactMap { a in a.calendarID.map { ($0, fields(of: a)) } }
                                     + deadlines.compactMap { d in d.calendarID.map { ($0, fields(of: d)) } })
        guard !reminderIDs.isEmpty || !eventIDs.isEmpty else { return result }
        var seen = await worker.look(events: eventIDs, reminders: reminderIDs)
        guard !Task.isCancelled else { return result }

        // A task whose reminder is no longer found by its id — iCloud can give a reminder a new
        // one once it has it — found again by its words, and connected anew. A reminder another
        // task is connected with already is not taken. Only when everything was asked for.
        if !onlyChangedHere {
            let lost = todos.filter { todo in !todo.isDone && todo.reminderID.map { seen.reminders[$0] == nil } == true }
            if !lost.isEmpty {
                let all = await calendars.allReminders()
                guard !Task.isCancelled else { return result }
                var taken = Set(todos.compactMap(\.reminderID))
                var found: [String] = []
                for todo in lost where still(todo, fields(of: todo)) {
                    guard let match = Calendars.findReminder(todo.text, in: all.filter { !taken.contains($0.id) }, ownLists: calendars.ownLists) else { continue }
                    todo.reminderID = match.id
                    taken.insert(match.id)
                    found.append(match.id)
                }
                if !found.isEmpty {
                    let more = await worker.look(events: [], reminders: found)
                    guard !Task.isCancelled else { return result }
                    seen.reminders.merge(more.reminders) { $1 }
                }
            }
        }

        // What goes out, and the stamp each is in step with once it is there: remembered over a
        // failed write, the old state there would count as the owner's newer one next time.
        var writes: [CalendarWorker.Write] = []
        var inStep: [(key: String, stamp: String)?] = []
        func send(_ write: CalendarWorker.Write, then stamp: (key: String, stamp: String)? = nil) {
            writes.append(write)
            inStep.append(stamp)
        }

        let keptTodos = oneEach(todos.compactMap { todo in todo.reminderID.map { (key: todo.persistentModelID, id: $0, local: asked[todo.persistentModelID] ?? []) } },
                                stamp: { stamps["reminder:" + $0] }, remote: { seen.reminders[$0]?.fields })
        for todo in todos where keptTodos.contains(todo.persistentModelID) {
            guard let id = todo.reminderID, let theirs = seen.reminders[id], still(todo, fields(of: todo)) else { continue }
            let key = "reminder:" + id
            var remote = theirs.fields
            // Seen here for the first time and done on one side only: a reminder is connected while
            // its task is open, so one of them was ticked since — and then both are done. Without
            // this, a task ticked before this device had looked once left its reminder open for good.
            if stamps[key] == nil, todo.isDone != (remote[3] == "done") {
                if todo.isDone {
                    send(.completed(id: id))
                    remote[3] = "done"
                } else {
                    todo.isDone = true
                    todo.doneAt = theirs.completedAt ?? Date()
                    result.pulled += 1
                }
            }
            let merge = Self.merge(local: fields(of: todo), remote: remote, stamp: stamps[key])
            if merge.pulled {
                let l = merge.local
                if !l[0].isEmpty { todo.text = l[0] }
                todo.due = l[1].isEmpty ? nil : l[1]
                todo.dueTime = l[2].isEmpty ? nil : l[2]
                let done = l[3] == "done"
                if done != todo.isDone {
                    todo.isDone = done
                    todo.doneAt = done ? (theirs.completedAt ?? Date()) : nil
                    if !done { todo.doneSource = nil }
                }
                result.pulled += 1
            }
            if merge.pushed { send(.reminder(id: id, fields: merge.remote), then: (key, merge.stamp)) } else { stamps[key] = merge.stamp }
        }

        let keptEvents = oneEach(appointments.compactMap { a in a.calendarID.map { (key: a.persistentModelID, id: $0, local: asked[a.persistentModelID] ?? []) } }
                                     + deadlines.compactMap { d in d.calendarID.map { (key: d.persistentModelID, id: $0, local: asked[d.persistentModelID] ?? []) } },
                                 stamp: { stamps["event:" + $0] }, remote: { seen.events[$0]?.fields })
        for appointment in appointments where keptEvents.contains(appointment.persistentModelID) {
            guard let id = appointment.calendarID, let theirs = seen.events[id], still(appointment, fields(of: appointment)) else { continue }
            let key = "event:" + id
            var end = theirs.end
            // An event Causabee made an hour long, as every one was, while the appointment knows
            // when it ends: given that end, before Calendar's end is taken as the owner's. One
            // whose length the owner has set is theirs.
            if theirs.madeByCausabee, !theirs.isAllDay, let start = theirs.start, let was = theirs.end,
               abs(was.timeIntervalSince(start) - 3_600) < 1,
               let span = Calendars.span(what: appointment.what, day: appointment.day, time: appointment.time,
                                         endDay: appointment.endDay, endTime: appointment.endTime),
               !span.allDay, abs(span.start.timeIntervalSince(start)) < 1, abs(span.end.timeIntervalSince(was)) > 1 {
                send(.end(id: id, at: span.end))
                end = span.end
            }
            let merge = Self.merge(local: fields(of: appointment), remote: theirs.fields, stamp: stamps[key])
            if merge.pulled {
                let l = merge.local
                appointment.what = l[0]; appointment.day = l[1]
                appointment.time = l[2].isEmpty ? nil : l[2]; appointment.place = l[3].isEmpty ? nil : l[3]
                result.pulled += 1
            }
            // The end is Calendar's to say: what the owner set there is kept here.
            if let start = theirs.start, let end {
                let last = Self.end(start: start, end: end, allDay: theirs.isAllDay)
                if appointment.endDay != last.day { appointment.endDay = last.day }
                if appointment.endTime != last.time { appointment.endTime = last.time }
            }
            if merge.pushed { send(.event(id: id, fields: merge.remote), then: (key, merge.stamp)) } else { stamps[key] = merge.stamp }
        }
        for deadline in deadlines where keptEvents.contains(deadline.persistentModelID) {
            guard let id = deadline.calendarID, let theirs = seen.events[id], still(deadline, fields(of: deadline)) else { continue }
            let key = "event:" + id
            let merge = Self.merge(local: fields(of: deadline), remote: [theirs.fields[0], theirs.fields[1]], stamp: stamps[key])
            if merge.pulled { deadline.what = merge.local[0]; deadline.day = merge.local[1]; result.pulled += 1 }
            if merge.pushed {
                send(.deadline(id: id, what: merge.remote[0], day: merge.remote[1]), then: (key, merge.stamp))
            } else {
                stamps[key] = merge.stamp
            }
        }

        guard !writes.isEmpty else { return result }
        // Kept in step even when cancelled meanwhile: what was written is there, and the stamps
        // are this device's, not the store's.
        for (index, written) in await worker.write(writes).enumerated() where written {
            result.pushed += 1
            if let stamp = inStep[index] { stamps[stamp.key] = stamp.stamp }
        }
        return result
    }

    nonisolated static func fields(of event: EKEvent) -> [String] {
        [event.title ?? "", MatterStatus.day(event.startDate), event.isAllDay ? "" : time(of: event.startDate), event.location ?? ""]
    }

    static func fields(of appointment: Appointment) -> [String] {
        [appointment.what, appointment.day, appointment.time ?? "", appointment.place ?? ""]
    }

    static func fields(of todo: Todo) -> [String] {
        [todo.text, todo.due ?? "", todo.dueTime ?? "", todo.isDone ? "done" : ""]
    }

    static func fields(of deadline: Deadline) -> [String] {
        [deadline.what, deadline.day]
    }

    nonisolated static func fields(of reminder: EKReminder) -> [String] {
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
    static func end(start: Date, end: Date, allDay: Bool) -> (day: String?, time: String?) {
        let first = MatterStatus.day(start), last = MatterStatus.day(end)
        if allDay { return (last > first ? last : nil, nil) }
        return (last > first ? last : nil, time(of: end))
    }

    /// A deadline knows only what and which day: the time and place the owner may have given it in
    /// Calendar stay as they are, and a new day keeps the event's own time and length.
    nonisolated static func writeDeadline(what: String, day: String, to event: EKEvent, store: EKEventStore) -> Bool {
        event.title = what
        if MatterStatus.day(event.startDate) != day,
           let start = Calendars.start(day: day, time: event.isAllDay ? nil : time(of: event.startDate)) {
            let length = event.endDate.timeIntervalSince(event.startDate)
            event.startDate = start
            event.endDate = start.addingTimeInterval(length)
        }
        return (try? store.save(event, span: .thisEvent, commit: false)) != nil
    }

    nonisolated static func write(_ fields: [String], to event: EKEvent, store: EKEventStore) -> Bool {
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
        return (try? store.save(event, span: .thisEvent, commit: false)) != nil
    }
}
