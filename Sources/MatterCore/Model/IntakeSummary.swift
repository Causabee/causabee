import Foundation

/// What a round of "Get new mail" came to, short: one line, and what it brought — the tasks and
/// the dates — each on a line of its own, so they can be seen without opening every matter.
public enum IntakeSummary {
    public struct Item: Sendable, Hashable {
        /// An SF Symbol: a task, an appointment, a deadline.
        public let symbol: String
        public let text: String

        public init(symbol: String, text: String) {
            self.symbol = symbol
            self.text = text
        }
    }

    /// "3 mails sorted into Lisbon · 1 new task" — or "into 3 matters" when there are several.
    public static func line(mails: Int, matters: [String], tasks: Int, dates: Int, unplaced: Int = 0, cost: Double? = nil) -> String {
        var text = "\(mails) \(mails == 1 ? "mail" : "mails") sorted"
        if matters.count == 1 { text += " into \(matters[0])" } else if matters.count > 1 { text += " into \(matters.count) matters" }
        if tasks > 0 { text += " · \(tasks) new \(tasks == 1 ? "task" : "tasks")" }
        if dates > 0 { text += " · \(dates) \(dates == 1 ? "date" : "dates")" }
        if unplaced > 0 { text += " · \(unplaced) without a matter, below" }
        if let cost { text += String(format: " · $%.3f", cost) }
        return text
    }

    /// The new tasks and dates, the first few.
    public static func items(_ judgements: [Judgement], limit: Int = 5) -> [Item] {
        let tasks = judgements.flatMap(\.todos).filter { $0.sameAs == nil }.map { Item(symbol: "checklist", text: $0.text) }
        let appointments = judgements.flatMap(\.appointments).map {
            Item(symbol: "calendar", text: "\(day($0.date))\($0.time.map { ", \($0)" } ?? "") · \($0.what)")
        }
        let deadlines = judgements.flatMap(\.deadlines).map { Item(symbol: "flag", text: "by \(day($0.date)) · \($0.what)") }
        return Array((tasks + appointments + deadlines).prefix(limit))
    }

    /// "2026-10-21" as "Oct 21".
    public static func day(_ day: String) -> String {
        let reader = DateFormatter()
        reader.locale = Locale(identifier: "en_US_POSIX")
        reader.dateFormat = "yyyy-MM-dd"
        guard let date = reader.date(from: day) else { return day }
        let writer = DateFormatter()
        writer.locale = Locale(identifier: "en_US")
        writer.dateFormat = "MMM d"
        return writer.string(from: date)
    }
}
