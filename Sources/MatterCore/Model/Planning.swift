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
            case .thisWeek: "This week"
            case .nextWeek: "Next week"
            case .later: "Later"
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

    /// How many days are left of this week, today and Sunday counted.
    public static func daysLeftInWeek(today: String) -> Int {
        guard let now = MatterStatus.date(of: today) else { return 7 }
        return 7 - (monday.component(.weekday, from: now) + 5) % 7
    }

    /// The week in one sentence, in parts — "This week: 3 things", "waiting on 2", "nothing
    /// slipping" — the parts that warn marked: what is overdue, what has no answer.
    public static func week(things: Int, waiting: Int, overdue: Int, unanswered: Int) -> [(text: String, warns: Bool)] {
        var parts: [(String, Bool)] = [(things == 0 ? "Nothing this week" : "This week: \(things) \(things == 1 ? "thing" : "things")", false)]
        if waiting > 0 { parts.append(("waiting on \(waiting)", false)) }
        if overdue > 0 { parts.append(("\(overdue) overdue", true)) }
        if unanswered > 0 { parts.append(("\(unanswered) without an answer", true)) }
        if overdue == 0, unanswered == 0 { parts.append(("nothing slipping", false)) }
        return parts
    }

    private static let monday: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }()
}
