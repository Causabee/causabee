import EventKit
import Foundation
import SwiftData

/// Connected appointments, deadlines and tasks kept in step with the owner's Calendar and
/// Reminders, both ways, field by field. Each remembers what both sides were when they were last
/// in step; a field that changed on one side since is written to the other, and when it changed
/// on both, the Calendar or Reminders side wins — the owner acted there most recently. What was
/// already different when they were connected — a task worded one way here, another there —
/// stays as it is on each side. Nothing that is not connected is touched.
@MainActor
public enum Mirror {
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

    /// Everything connected, both ways. Saves the store when something came in.
    public static func reconcile(_ context: ModelContext, calendars: Calendars = .shared) -> Result {
        var result = Result()
        if calendars.canReadReminders {
            for todo in (try? context.fetch(FetchDescriptor<Todo>())) ?? [] {
                guard let id = todo.reminderID, let reminder = calendars.reminder(id) else { continue }
                let parts = reminder.dueDateComponents
                let due = parts.flatMap { Calendar.current.date(from: $0) }.map { MatterStatus.day($0) } ?? ""
                let dueTime = (parts?.hour).map { String(format: "%02d:%02d", $0, parts?.minute ?? 0) } ?? ""
                let merge = Self.merge(local: [todo.text, todo.due ?? "", todo.dueTime ?? "", todo.isDone ? "done" : ""],
                                       remote: [reminder.title ?? "", due, dueTime, reminder.isCompleted ? "done" : ""],
                                       stamp: todo.reminderStamp)
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
                    guard (try? calendars.store.save(reminder, commit: false)) != nil else { continue }
                    result.pushed += 1
                }
                if todo.reminderStamp != merge.stamp { todo.reminderStamp = merge.stamp }
            }
        }
        if calendars.canReadEvents {
            for appointment in (try? context.fetch(FetchDescriptor<Appointment>())) ?? [] {
                guard let id = appointment.calendarID, let event = calendars.event(id) else { continue }
                let merge = Self.merge(local: [appointment.what, appointment.day, appointment.time ?? "", appointment.place ?? ""],
                                       remote: fields(of: event), stamp: appointment.calendarStamp)
                if merge.pulled {
                    let l = merge.local
                    appointment.what = l[0]; appointment.day = l[1]
                    appointment.time = l[2].isEmpty ? nil : l[2]; appointment.place = l[3].isEmpty ? nil : l[3]
                    result.pulled += 1
                }
                // In step only once Calendar has it too: a stamp over a failed write would take the
                // old Calendar value for the owner's newer one next time, and put it back.
                let written = !merge.pushed || write(merge.remote, to: event, calendars: calendars)
                if merge.pushed, written { result.pushed += 1 }
                if written, appointment.calendarStamp != merge.stamp { appointment.calendarStamp = merge.stamp }
            }
            for deadline in (try? context.fetch(FetchDescriptor<Deadline>())) ?? [] {
                guard let id = deadline.calendarID, let event = calendars.event(id) else { continue }
                let theirs = fields(of: event)
                let merge = Self.merge(local: [deadline.what, deadline.day], remote: [theirs[0], theirs[1]], stamp: deadline.calendarStamp)
                if merge.pulled { deadline.what = merge.local[0]; deadline.day = merge.local[1]; result.pulled += 1 }
                let written = !merge.pushed || writeDeadline(what: merge.remote[0], day: merge.remote[1], to: event, calendars: calendars)
                if merge.pushed, written { result.pushed += 1 }
                if written, deadline.calendarStamp != merge.stamp { deadline.calendarStamp = merge.stamp }
            }
        }
        if result.pushed > 0 { try? calendars.store.commit() }
        if context.hasChanges { try? context.save() }
        return result
    }

    static func fields(of event: EKEvent) -> [String] {
        [event.title ?? "", MatterStatus.day(event.startDate), event.isAllDay ? "" : time(of: event.startDate), event.location ?? ""]
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
        event.title = fields[0]
        event.isAllDay = time == nil
        event.startDate = start
        event.endDate = time == nil ? start : start.addingTimeInterval(length)
        event.location = fields[3].isEmpty ? nil : fields[3]
        return (try? calendars.store.save(event, span: .thisEvent, commit: false)) != nil
    }
}
