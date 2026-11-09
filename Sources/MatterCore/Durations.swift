import Foundation

/// How long an appointment takes, as the owner sets it: a length, not an end. Kept as its end
/// beside its start, so Calendar gets both.
public enum Durations {
    /// What to choose from, in minutes; 0 is "not set".
    public static let choices = [0, 15, 30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480]

    /// The choices, with the one it has now among them.
    public static func choices(with now: Int) -> [Int] { Array(Set(choices + [now])).sorted() }

    /// "Not set", "45 min", "1 h", "1 h 30 min".
    public static func label(_ minutes: Int) -> String {
        guard minutes > 0 else { return "Not set" }
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    /// From a start and an end on the same day; 0 when there is none, or it makes no sense.
    public static func minutes(from time: String?, to end: String?) -> Int {
        guard let start = Calendars.clock(time), let stop = Calendars.clock(end) else { return 0 }
        var length = (stop.0 * 60 + stop.1) - (start.0 * 60 + start.1)
        if length <= 0 { length += 24 * 60 }
        return length <= 12 * 60 ? length : 0
    }

    /// The end, `minutes` after `time`; nil for none.
    public static func end(from time: String?, minutes: Int) -> String? {
        guard minutes > 0, let start = Calendars.clock(time) else { return nil }
        let to = (start.0 * 60 + start.1 + minutes) % (24 * 60)
        return String(format: "%02d:%02d", to / 60, to % 60)
    }
}
