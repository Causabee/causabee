import Foundation

/// One thing on a day, from any open matter: a task due then, a deadline or an appointment.
public struct DayThing {
    public let matter: Matter
    public let what: String
    /// `HH:MM`, for an appointment with a time.
    public let time: String?
    /// The task it is, to open its matter at it; nil for a deadline or an appointment.
    public let todo: Todo?
}

/// The overview's week: the next days across all open matters, and what is on each — the same
/// things `MatterStatus.next` looks at, so a matter's "Next" is always somewhere in the week.
public enum Week {
    /// `count` days from `today` on, as the store writes a day.
    public static func days(from today: Date = Date(), count: Int = 7) -> [String] {
        (0..<count).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }.map(MatterStatus.day)
    }

    /// What is on `day` in the open matters: appointments by their time first, then the rest,
    /// matter by matter.
    public static func things(on day: String, in matters: [Matter]) -> [DayThing] {
        matters.filter { !$0.isClosed }.flatMap { matter -> [DayThing] in
            var things = matter.openTodos.filter { $0.due == day }.map { DayThing(matter: matter, what: $0.text, time: nil, todo: $0) }
            things += (matter.deadlines ?? []).filter { $0.day == day }.map { DayThing(matter: matter, what: $0.what, time: nil, todo: nil) }
            things += (matter.appointments ?? []).filter { $0.day == day }.map { DayThing(matter: matter, what: $0.what, time: $0.time, todo: nil) }
            return things
        }
        .sorted { ($0.time ?? "99", $0.matter.name) < ($1.time ?? "99", $1.matter.name) }
    }

    /// Today's things as the day goes on: what is still ahead, and what is over — an appointment
    /// whose end has passed: the end its words say ("11:00–12:30"), or an hour after it begins.
    /// A task or a deadline has no hour, and is ahead for as long as its day lasts. On any other
    /// day everything is ahead.
    public static func asTheDayGoes(_ things: [DayThing], on day: String, now: Date = Date()) -> (ahead: [DayThing], over: [DayThing]) {
        guard day == MatterStatus.day(now), let midnight = MatterStatus.date(of: day) else { return (things, []) }
        func isOver(_ thing: DayThing) -> Bool {
            guard let time = thing.time else { return false }
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, let start = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: midnight) else { return false }
            return (Calendars.end(in: thing.what, from: start) ?? start.addingTimeInterval(3600)) <= now
        }
        return (things.filter { !isOver($0) }, things.filter(isOver))
    }

    /// The first day after `day` with anything on it, and its first thing: what an empty day
    /// says comes next.
    public static func next(after day: String, in matters: [Matter]) -> (day: String, thing: DayThing)? {
        let later = matters.filter { !$0.isClosed }.flatMap { matter in
            matter.openTodos.compactMap(\.due) + (matter.deadlines ?? []).map(\.day) + (matter.appointments ?? []).map(\.day)
        }
        guard let first = later.filter({ $0 > day }).min(), let thing = things(on: first, in: matters).first else { return nil }
        return (first, thing)
    }
}

extension Matter {
    public var isPinned: Bool { pinnedAt != nil }
}

/// The matters the owner keeps on top of the overview.
public enum Pins {
    /// More would push the week and everything else off the screen.
    public static let most = 3

    /// The pinned open matters, in the order they were pinned.
    public static func pinned(_ matters: [Matter]) -> [Matter] {
        matters.filter { !$0.isClosed && $0.pinnedAt != nil }.sorted { ($0.pinnedAt ?? .distantPast) < ($1.pinnedAt ?? .distantPast) }
    }
}
