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
        // "Mail" alone is no message: "trace the email imports" is not one, "Mail an die Bank" is.
        let german = ["nachfass", "nachfrag", "nachhak", "erinner", "schreib", "anschreib", "antwort geben", "beantwort",
                      "rückmeld", "zurückmeld", "melden", "kontaktier", "anfrag", "bescheid geben", "mitteil", "informier", "absag", "zusag",
                      "schick", "send", "übermittel", "weiterleit", "mail an "]
        // English: a step that begins with one of these is a message to someone. Further in, "email"
        // is as often a thing as a deed.
        let english = ["write to", "reply", "respond", "email ", "e-mail ", "ask ", "tell ", "remind ", "follow up", "contact ", "let ",
                       "inform ", "forward ", "send "]
        return (german.contains { words.contains($0) } || english.contains { words.hasPrefix($0) })
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
    public var lastChange: Date? { (todos ?? []).shown.flatMap { [$0.createdAt, $0.doneAt].compactMap { $0 } }.max() }

    /// What the matter's record holds, as one short word that is another whenever the record is:
    /// a mail taken in or moved away, a file, a task added, changed or done, a date, a note. Not
    /// the next step and the summary themselves — they are written from it — and not the day it
    /// is, so that nothing looks changed only because a night went by.
    public var recordStamp: String {
        var parts: [String] = []
        parts += (entries ?? []).map { "m|" + $0.messageID }
        parts += (documents ?? []).filter { !$0.isHidden }.map { "f|" + $0.messageID + "|" + $0.name }
        parts += (todos ?? []).shown.map { "t|\($0.origin)|\($0.text)|\($0.isDone)|\($0.due ?? "")|\($0.dueTime ?? "")|\($0.owner.rawValue)|\($0.note ?? "")" }
        parts += (appointments ?? []).shown.map { "a|\($0.what)|\($0.day)|\($0.time ?? "")|\($0.place ?? "")" }
        parts += (deadlines ?? []).shown.map { "d|\($0.what)|\($0.day)" }
        parts.append("n|" + (notesText ?? ""))
        // What the owner said of the matter: the brief is written again around it.
        parts += (shownBrief?.said ?? []).map { "s|" + $0.text }
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
        case .overdue: String(localized: "Overdue", bundle: .module)
        case .date: String(localized: "Soon", bundle: .module)
        case .doIt: String(localized: "Next", bundle: .module)
        case .followUp: String(localized: "Follow up", bundle: .module)
        case .wait: String(localized: "Wait", bundle: .module)
        }
    }

    /// The label, and where a step that is one of the owner's tasks comes from.
    public var heading: String {
        todo == nil ? label : String(format: String(localized: "%@ · from your tasks", bundle: .module), label)
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
            return waiting.count == 1
                ? String(localized: " Then this can go ahead: ", bundle: .module) + Self.sentence(first.text)
                : String(format: String(localized: " Then %lld more tasks can go ahead.", bundle: .module), waiting.count)
        }
        func step(_ kind: NextStep.Kind, _ todo: Todo, _ why: String) -> NextStep {
            NextStep(kind: kind, text: todo.text, why: (why + then(todo)).trimmingCharacters(in: .whitespaces), todo: todo.persistentModelID)
        }

        if let late = mine.filter({ ($0.due ?? "9999") < today }).min(by: byDay) {
            return step(.overdue, late, Self.sentence(String(format: String(localized: "Overdue since %@", bundle: .module), Self.short(late.due ?? today))))
        }
        let horizon = Self.day(Calendar.current.date(byAdding: .day, value: Self.soon, to: Self.date(today) ?? Date()) ?? Date())
        let appointment = String(localized: "Appointment", bundle: .module), deadline = String(localized: "Deadline", bundle: .module)
        var dates: [(day: String, time: String?, what: String, kind: String)] = (matter.appointments ?? []).shown.map { ($0.day, $0.time, $0.what, appointment) }
        dates += (matter.deadlines ?? []).shown.map { ($0.day, nil, $0.what, deadline) }
        let upcoming = dates.filter { $0.day >= today }.sorted { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }
        if let near = upcoming.first(where: { $0.day <= horizon }) {
            let when = near.day == today ? String(localized: "today", bundle: .module)
                : String(format: String(localized: "on %@", bundle: .module), Self.short(near.day))
            let at = near.time.map { String(format: String(localized: " at %@", bundle: .module), $0) } ?? ""
            return NextStep(kind: .date, text: near.what, why: Self.sentence("\(near.kind) \(when)\(at)"), todo: nil)
        }
        if let late = theirs.filter({ ($0.due ?? "9999") < today }).min(by: byDay) {
            let due = Self.sentence(String(format: String(localized: "Should have come by %@", bundle: .module), Self.short(late.due ?? today)))
            return step(.followUp, late, due + " " + String(localized: "A short follow-up helps.", bundle: .module))
        }
        if let first = mine.min(by: byDay) {
            let why = first.isFreed ? String(localized: "What it waited for is done.", bundle: .module)
                : first.due.map { Self.sentence(String(format: String(localized: "Due on %@", bundle: .module), Self.short($0))) }
                ?? Self.sentence(String(format: String(localized: "The oldest open task, since %@", bundle: .module), Self.short(first.createdAt)))
            return step(.doIt, first, why)
        }
        if let first = theirs.min(by: byDay) {
            // A day of its own carries a full stop in German — "12. Nov." — so the sentence is
            // closed by `sentence`, which adds one only where there is none (F009).
            let why = first.due.map {
                Self.sentence(String(format: String(localized: "Wait until %@", bundle: .module), Self.short($0)))
                    + " " + String(localized: "If nothing comes, follow up.", bundle: .module)
            } ?? String(localized: "Nothing for you to do until it comes.", bundle: .module)
            return step(.wait, first, why)
        }
        if let later = upcoming.first {
            let when = String(format: String(localized: "on %@", bundle: .module), Self.short(later.day))
            return NextStep(kind: .date, text: later.what, why: Self.sentence("\(later.kind) \(when)"), todo: nil)
        }
        return nil
    }

    /// A full stop at the end, once: "Fällig am 30. Sept." and not "Sept..".
    static func sentence(_ text: String) -> String { text.hasSuffix(".") ? text : text + "." }

    /// `2026-10-13` → `13. Okt.`, as the app writes a day.
    static func short(_ day: String) -> String { date(day).map(short) ?? day }
    static func short(_ date: Date) -> String {
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return sameYear ? date.formatted(.dateTime.day().month(.abbreviated))
                        : date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func date(_ day: String) -> Date? { MatterStatus.date(of: day) }
}
