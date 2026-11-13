import Foundation

/// A task with a day is a plan, and a plan is what lets the mind let go of it (Masicampo and
/// Baumeister 2011, "Consider it done!"). So a task without a day is given one in a tap, someone
/// else's comes back when its answer is due, and the week says in one sentence whether anything
/// slips (docs/digest-and-chat.md, 6 November 2026). Nothing new is stored: a day is the task's
/// own `due`, and when someone else's comes back is read from what it has.
public enum Planning {
    /// The three answers to "When?": this week, next week, or later — and later is a day too.
    public enum When: String, CaseIterable, Sendable {
        case thisWeek, nextWeek, later

        public var label: String {
            switch self {
            case .thisWeek: String(localized: "This week", bundle: .module)
            case .nextWeek: String(localized: "Next week", bundle: .module)
            case .later: String(localized: "Later", bundle: .module)
            }
        }
    }

    /// How long someone else's task waits, when it has no day of its own, before it comes back.
    public static let waitsFor = 7
    /// How far "Later" is.
    public static let laterDays = 28

    /// The day "When?" was answered with, `YYYY-MM-DD`: this week's Friday — today, once it is the
    /// weekend — next week's Friday, or four weeks on.
    public static func day(_ when: When, today: String) -> String {
        guard let now = MatterStatus.date(of: today) else { return today }
        // Monday is 0, Friday 4.
        let weekday = (monday.component(.weekday, from: now) + 5) % 7
        let days: Int
        switch when {
        case .thisWeek: days = max(0, 4 - weekday)
        case .nextWeek: days = 7 - weekday + 4
        case .later: days = laterDays
        }
        return MatterStatus.day(monday.date(byAdding: .day, value: days, to: now) ?? now)
    }

    /// The day someone else's task comes back to the owner: its own day, or a week after it came.
    public static func comesBack(_ todo: Todo) -> String {
        if let due = todo.due { return due }
        return MatterStatus.day(monday.date(byAdding: .day, value: waitsFor, to: todo.createdAt) ?? todo.createdAt)
    }

    /// Whether someone else's task is back with the owner today: no answer by its day.
    public static func isBack(_ todo: Todo, today: String) -> Bool {
        todo.owner == .other && !todo.isDone && comesBack(todo) <= today
    }

    /// One more week of waiting, from today.
    public static func waitAWeek(_ todo: Todo, today: String) {
        guard let now = MatterStatus.date(of: today) else { return }
        todo.due = MatterStatus.day(monday.date(byAdding: .day, value: waitsFor, to: now) ?? now)
    }

    /// One reminder to be told the day before: the owner's task or a deadline, in its matter.
    public struct Reminder: Equatable, Sendable {
        /// The same for the same thing, so a reminder planned again replaces itself.
        public var id: String
        public var matter: String
        public var matterKey: String
        public var text: String
        public var isDeadline: Bool
        /// When it is told: the day before, at `remindAt`.
        public var at: Date
    }

    /// The hour of the day before at which a reminder is told.
    public static let remindAt = 9
    /// At most this many are planned at once — iOS keeps 64 — the soonest first.
    public static let mostReminders = 50

    /// What to remind the owner of, the day before at nine: their own open tasks with a day, and
    /// the deadlines, in the open matters — only what is still to come. Someone else's task is not
    /// told; it comes back as "No answer yet" instead.
    public static func reminders(_ matters: [Matter], now: Date = Date()) -> [Reminder] {
        var out: [Reminder] = []
        func at(_ day: String) -> Date? {
            guard let date = MatterStatus.date(of: day), let before = monday.date(byAdding: .day, value: -1, to: date) else { return nil }
            return monday.date(bySettingHour: remindAt, minute: 0, second: 0, of: before)
        }
        for matter in matters where !matter.isClosed {
            for todo in matter.openTodos where todo.owner != .other && !todo.isInfo && !todo.isHidden {
                guard let due = todo.due, let when = at(due), when > now else { continue }
                out.append(Reminder(id: "due-t-" + matter.key + "-" + todo.origin, matter: matter.name, matterKey: matter.key,
                                    text: todo.text, isDeadline: false, at: when))
            }
            for deadline in matter.deadlines ?? [] where !deadline.isHidden {
                guard let when = at(deadline.day), when > now else { continue }
                out.append(Reminder(id: "due-d-" + matter.key + "-" + deadline.day + "-" + MatterImport.key(deadline.what),
                                    matter: matter.name, matterKey: matter.key, text: deadline.what, isDeadline: true, at: when))
            }
        }
        return Array(out.sorted { $0.at < $1.at }.prefix(mostReminders))
    }

    private static let monday: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }()
}
