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

    /// One mail of the round, and the matter it went into: to move it when that is the wrong one.
    public struct Mail: Sendable, Hashable {
        public let messageID: String
        public let subject: String
        public var matter: String

        public init(messageID: String, subject: String, matter: String) {
            self.messageID = messageID
            self.subject = subject
            self.matter = matter
        }
    }

    /// One mail of a round as it was read, before any of it is taken in: where it would go, and
    /// what it would bring. The owner decides on these — which to take in, and into which matter.
    public struct Offer: Sendable, Identifiable {
        /// The mail's id, as its judgement has it.
        public let id: String
        public let subject: String
        /// The matter it would go into; nil when none was found.
        public let matter: String?
        /// That matter does not exist yet: taking the mail in makes it.
        public let isNew: Bool
        public let items: [Found]
    }

    /// One thing a mail brings — a task, an appointment, a deadline — by its place in the answer:
    /// "t0", "a1", "d0". The owner takes it or leaves it.
    public struct Found: Sendable, Hashable, Identifiable {
        public let key: String
        public let symbol: String
        public let text: String
        public var id: String { key }
    }

    /// What the answer found in one mail, each with its key. A task the matter has already is not
    /// listed: it is not added twice.
    public static func found(in judgement: Judgement) -> [Found] {
        judgement.todos.enumerated().filter { $0.element.sameAs == nil }.map { Found(key: "t\($0.offset)", symbol: "checklist", text: $0.element.text) }
            + judgement.appointments.enumerated().map {
                Found(key: "a\($0.offset)", symbol: "calendar", text: "\(day($0.element.date))\($0.element.time.map { ", \($0)" } ?? "") · \($0.element.what)")
            }
            + judgement.deadlines.enumerated().map { Found(key: "d\($0.offset)", symbol: "flag", text: "by \(day($0.element.date)) · \($0.element.what)") }
    }

    /// The answer without what the owner left out, by the keys of `found(in:)`.
    public static func leaving(out skipped: Set<String>, of judgement: Judgement) -> Judgement {
        guard !skipped.isEmpty else { return judgement }
        var judgement = judgement
        judgement.todos = judgement.todos.enumerated().filter { !skipped.contains("t\($0.offset)") }.map(\.element)
        judgement.appointments = judgement.appointments.enumerated().filter { !skipped.contains("a\($0.offset)") }.map(\.element)
        judgement.deadlines = judgement.deadlines.enumerated().filter { !skipped.contains("d\($0.offset)") }.map(\.element)
        return judgement
    }

    /// What the round's answers offer, one for each mail that is not a newsletter. `name` gives an
    /// existing matter's name for a key, or nil when there is none yet.
    public static func offers(_ judgements: [Judgement], name: (String) -> String?) -> [Offer] {
        judgements.filter { !$0.isBulk }.map { judgement in
            let known = judgement.matter.flatMap(name)
            let made = judgement.matter.map { judgement.matterTitle ?? ($0.prefix(1).uppercased() + $0.dropFirst()) }
            return Offer(id: judgement.emailID, subject: judgement.subject.isEmpty ? "(no subject)" : judgement.subject,
                         matter: known ?? made, isNew: known == nil && made != nil, items: found(in: judgement))
        }
    }

    /// The mails sorted into a matter, each with that matter's name — the first few.
    public static func mails(_ judgements: [Judgement], name: (String) -> String?, limit: Int = 6) -> [Mail] {
        Array(judgements.compactMap { judgement -> Mail? in
            guard !judgement.isBulk, let key = judgement.matter, let matter = name(key) else { return nil }
            return Mail(messageID: judgement.emailID, subject: judgement.subject.isEmpty ? "(no subject)" : judgement.subject, matter: matter)
        }.prefix(limit))
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
