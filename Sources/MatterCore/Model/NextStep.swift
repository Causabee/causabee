import CryptoKit
import Foundation
import SwiftData

extension Todo {
    /// It waits for a to-do that is still open: it cannot be done yet.
    public var isBlocked: Bool { waitsFor.map { !$0.isDone && !$0.isInfo } ?? false }

    /// What it waited for is done, and it is not: it can be done now.
    public var isFreed: Bool { !isDone && (waitsFor?.isDone ?? false) }

    /// Done by writing to someone: following up, asking, reminding, answering. The step for it
    /// is a message to write, not only a box to tick.
    public var isMessage: Bool { Self.isMessage(text) }

    public static func isMessage(_ text: String) -> Bool {
        let words = text.lowercased()
        return ["nachfass", "nachfrag", "nachhak", "erinner", "schreib", "anschreib", "mail", "antwort geben", "beantwort",
                "rückmeld", "zurückmeld", "melden", "kontaktier", "anfrag", "bescheid geben", "mitteil", "informier", "absag", "zusag",
                "schick", "send", "übermittel", "weiterleit"]
            .contains { words.contains($0) }
            && !words.contains("abwarten")
    }

    /// The open to-dos that wait for this one.
    public var waiting: [Todo] { (unblocks ?? []).filter { !$0.isDone && !$0.isInfo } }

    /// Makes it wait for another — never for itself, and never round in a circle, where each of
    /// two would wait for the other and neither could ever be done. Says whether it did.
    @discardableResult
    public func wait(for other: Todo?) -> Bool {
        guard let other else { waitsFor = nil; return true }
        var step: Todo? = other
        var seen = 0
        while let current = step, seen < 50 {
            if current === self { return false }
            step = current.waitsFor
            seen += 1
        }
        waitsFor = other
        return true
    }
}

extension Matter {
    /// When its to-dos last changed: one came in, one was done.
    public var lastChange: Date? { (todos ?? []).flatMap { [$0.createdAt, $0.doneAt].compactMap { $0 } }.max() }

    /// What the matter's record holds, as one short word that is another whenever the record is:
    /// a mail taken in or moved away, a file, a task added, changed or done, a date, a note. Not
    /// the next step and the summary themselves — they are written from it — and not the day it
    /// is, so that nothing looks changed only because a night went by.
    public var recordStamp: String {
        var parts: [String] = []
        parts += (entries ?? []).map { "m|" + $0.messageID }
        parts += (documents ?? []).filter { !$0.isHidden }.map { "f|" + $0.messageID + "|" + $0.name }
        parts += (todos ?? []).map { "t|\($0.origin)|\($0.text)|\($0.isDone)|\($0.due ?? "")|\($0.dueTime ?? "")|\($0.owner.rawValue)|\($0.note ?? "")" }
        parts += (appointments ?? []).map { "a|\($0.what)|\($0.day)|\($0.time ?? "")|\($0.place ?? "")" }
        parts += (deadlines ?? []).map { "d|\($0.what)|\($0.day)" }
        parts.append("n|" + (notesText ?? ""))
        let digest = SHA256.hash(data: Data(parts.sorted().joined(separator: "\n").utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

/// The one thing to do next in a matter, and why — worked out on the device from what is open,
/// whose it is, what waits for what, and the dates. Free, and sends nothing.
public struct NextStep: Sendable, Equatable {
    public enum Kind: String, Sendable {
        /// The owner's own, past its day.
        case overdue
        /// An appointment or a deadline in the next few days.
        case date
        /// The owner's own, nothing in its way.
        case doIt
        /// Someone else's the owner waits for, past its day: time to ask.
        case followUp
        /// Only waiting, and not yet late.
        case wait
    }

    public var kind: Kind
    public var text: String
    public var why: String
    public var todo: PersistentIdentifier?

    /// The label over it, in the app's words.
    public var label: String {
        switch kind {
        case .overdue: "Overdue"
        case .date: "Soon"
        case .doIt: "Next"
        case .followUp: "Follow up"
        case .wait: "Wait"
        }
    }
}

extension MatterStatus {
    /// Days ahead in which an appointment or a deadline comes before anything else.
    static let soon = 3

    public var nextStep: NextStep? {
        let open = matter.openTodos.filter { !$0.isBlocked }
        let mine = open.filter { $0.owner != .other }
        let theirs = open.filter { $0.owner == .other }
        func byDay(_ a: Todo, _ b: Todo) -> Bool {
            // What frees another to-do goes first on the same day; then what was asked first.
            (a.due ?? "9999", a.waiting.isEmpty ? 1 : 0, a.createdAt) < (b.due ?? "9999", b.waiting.isEmpty ? 1 : 0, b.createdAt)
        }
        func then(_ todo: Todo) -> String {
            let waiting = todo.waiting
            guard let first = waiting.first else { return "" }
            return waiting.count == 1 ? " Then this can go ahead: \(first.text)." : " Then \(waiting.count) more tasks can go ahead."
        }
        func step(_ kind: NextStep.Kind, _ todo: Todo, _ why: String) -> NextStep {
            NextStep(kind: kind, text: todo.text, why: (why + then(todo)).trimmingCharacters(in: .whitespaces), todo: todo.persistentModelID)
        }

        if let late = mine.filter({ ($0.due ?? "9999") < today }).min(by: byDay) {
            return step(.overdue, late, "Overdue since \(Self.short(late.due ?? today)).")
        }
        let horizon = Self.day(Calendar.current.date(byAdding: .day, value: Self.soon, to: Self.date(today) ?? Date()) ?? Date())
        var dates: [(day: String, time: String?, what: String, kind: String)] = (matter.appointments ?? []).map { ($0.day, $0.time, $0.what, "Appointment") }
        dates += (matter.deadlines ?? []).map { ($0.day, nil, $0.what, "Deadline") }
        let upcoming = dates.filter { $0.day >= today }.sorted { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }
        if let near = upcoming.first(where: { $0.day <= horizon }) {
            let when = near.day == today ? "today" : "on \(Self.short(near.day))"
            return NextStep(kind: .date, text: near.what,
                            why: Self.sentence("\(near.kind) \(when)\(near.time.map { " at \($0)" } ?? "")"), todo: nil)
        }
        if let late = theirs.filter({ ($0.due ?? "9999") < today }).min(by: byDay) {
            return step(.followUp, late, "Should have come by \(Self.short(late.due ?? today)). A short follow-up helps.")
        }
        if let first = mine.min(by: byDay) {
            let why = first.isFreed ? "What it waited for is done."
                : first.due.map { Self.sentence("Due on \(Self.short($0))") }
                ?? Self.sentence("The oldest open task, since \(Self.short(first.createdAt))")
            return step(.doIt, first, why)
        }
        if let first = theirs.min(by: byDay) {
            let why = first.due.map { "Wait until \(Self.short($0)). If nothing comes, follow up." } ?? "Nothing for you to do until it comes."
            return step(.wait, first, why)
        }
        if let later = upcoming.first {
            return NextStep(kind: .date, text: later.what, why: Self.sentence("\(later.kind) on \(Self.short(later.day))"), todo: nil)
        }
        return nil
    }

    /// A full stop at the end, once: "Fällig am 30. Sept." and not "Sept..".
    static func sentence(_ text: String) -> String { text.hasSuffix(".") ? text : text + "." }

    /// `2026-10-13` → `13. Okt.`, as the app writes a day.
    static func short(_ day: String) -> String { date(day).map(short) ?? day }
    static func short(_ date: Date) -> String {
        let english = Locale(identifier: "en_US")
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return sameYear ? date.formatted(.dateTime.day().month(.abbreviated).locale(english))
                        : date.formatted(.dateTime.day().month(.abbreviated).year().locale(english))
    }

    static func date(_ day: String) -> Date? { MatterStatus.date(of: day) }
}
