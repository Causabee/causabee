import Foundation
import SwiftData

/// What a status view shows about a matter, worked out once so the Mac and the iPhone show the
/// same thing: what is open and whose, what comes next, and when anything last happened.
public struct MatterStatus {
    public let matter: Matter
    public let today: String

    public init(_ matter: Matter, today: Date = Date()) {
        self.matter = matter
        self.today = Self.day(today)
    }

    /// "2026-09-29": read from the calendar, not by a date formatter — making one is slow, and a
    /// matter's status is asked for many times each time the screen is drawn.
    public static func day(_ date: Date) -> String {
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The way back: "2026-09-29" → that day's start where the Mac is. Nil for anything that is not
    /// a real day — "2026-02-31" does not roll over into March.
    public static func date(of day: String) -> Date? {
        let parts = day.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let dayOfMonth = Int(parts[2]) else { return nil }
        let components = DateComponents(year: year, month: month, day: dayOfMonth)
        guard components.isValidDate(in: gregorian) else { return nil }
        return gregorian.date(from: components)
    }

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    /// Whose they are, by day — and what waits for another to-do last, however early its day:
    /// it cannot be done yet.
    public func open(_ owner: Todo.Owner) -> [Todo] {
        matter.openTodos.filter { $0.owner == owner }.sorted {
            ($0.isBlocked ? 1 : 0, $0.due ?? "9999", $0.createdAt) < ($1.isBlocked ? 1 : 0, $1.due ?? "9999", $1.createdAt)
        }
    }

    public var done: [Todo] { (matter.todos ?? []).filter { $0.isDone && !$0.isInfo }.sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) } }

    public var upcomingAppointments: [Appointment] {
        (matter.appointments ?? []).filter { $0.day >= today }.sorted { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }
    }

    public var pastAppointments: [Appointment] {
        (matter.appointments ?? []).filter { $0.day < today }.sorted { ($0.day, $0.time ?? "") > ($1.day, $1.time ?? "") }
    }

    public var deadlines: [Deadline] { (matter.deadlines ?? []).sorted { $0.day < $1.day } }

    public var entries: [Entry] { (matter.entries ?? []).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) } }

    public var firstDate: Date? { (matter.entries ?? []).compactMap(\.date).min() }
    public var lastDate: Date? { (matter.entries ?? []).compactMap(\.date).max() }

    /// The next thing with a date on it: an open to-do's due day, a deadline, an appointment.
    public var next: (day: String, what: String)? {
        var dated: [(String, String)] = matter.openTodos.compactMap { todo in todo.due.map { ($0, todo.text) } }
        dated += (matter.deadlines ?? []).map { ($0.day, $0.what) }
        dated += (matter.appointments ?? []).map { ($0.day, $0.what) }
        return dated.filter { $0.0 >= today }.min { $0.0 < $1.0 }.map { (day: $0.0, what: $0.1) }
    }

    /// Open to-dos past their day. One that still waits for another is not late yet: what it
    /// waits for is.
    public var overdue: [Todo] { matter.openTodos.filter { !$0.isBlocked && ($0.due ?? "9999") < today } }

    public var memberships: [Membership] {
        // Named most often first; people named as often by name, so the order is the same every time.
        (matter.memberships ?? []).filter { $0.party != nil }.sorted {
            $0.mentions != $1.mentions ? $0.mentions > $1.mentions
                : ($0.party?.name ?? "").localizedStandardCompare($1.party?.name ?? "") == .orderedAscending
        }
    }
}

extension Entry {
    /// Opens the mail in Mail.app, when Mail has the account.
    public var mailURL: URL? { source.mailURL }
}

extension Source {
    /// The image or document it came from, when that is a file on this Mac.
    public var fileURL: URL? {
        // A mail from the label is in the mailbox; a mail dropped in as `.eml` is a file.
        guard !pointer.hasPrefix("imap://") else { return nil }
        let url = pointer.hasPrefix("file://") ? URL(string: pointer) : URL(fileURLWithPath: pointer)
        return url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }

    /// `message://<Message-ID>`: Mail.app opens the original, if it has the account.
    public var mailURL: URL? {
        guard kind == .mail, let id = messageID, !id.isEmpty,
              let encoded = "<\(id)>".addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "@.-_"))) else {
            return nil
        }
        return URL(string: "message://" + encoded)
    }
}

extension PartyBook {
    /// The owner says two parties are one. Kept as a rule, so it holds for the next mail.
    public static func confirmSame(_ party: Party, as other: Party, in matter: Matter, context: ModelContext, origin: String) {
        guard party !== other else { return }
        context.insert(Rule(.sameParty, subject: party.name, object: other.name, matterKey: matter.key, origin: origin))
        merge(party, into: other, context: context)
    }

    /// The owner says they are two. Kept, so the pair is not suggested again.
    public static func refuseSame(_ party: Party, as other: Party, in matter: Matter, context: ModelContext, origin: String) {
        context.insert(Rule(.notSameParty, subject: party.name, object: other.name, matterKey: matter.key, origin: origin))
    }
}

extension Matter {
    public var isClosed: Bool { closedAt != nil }

    /// The pointer a to-do gets when closing the matter ticked it, so reopening can tell those
    /// apart from the ones that were done before.
    static let closingPointer = "matter-closed"

    /// Closes the matter. Nothing is deleted: its mail, to-dos and people stay, and it can be
    /// opened and read. `markingOpenDone` ticks what is still open, and remembers that it did.
    public func close(markingOpenDone: Bool, at date: Date = Date()) {
        if markingOpenDone {
            for todo in openTodos {
                todo.isDone = true
                todo.doneAt = date
                todo.doneSource = Source(kind: .conversation, pointer: Self.closingPointer, date: date, quote: "marked done when the matter was closed")
            }
        }
        closedAt = date
    }

    /// Opens it again. What closing ticked is open again too; what was done before stays done.
    public func reopen() {
        for todo in todos ?? [] where todo.doneSource?.pointer == Self.closingPointer {
            todo.isDone = false
            todo.doneAt = nil
            todo.doneSource = nil
        }
        closedAt = nil
    }
}

extension MatterStatus {
    /// Mail that came in after the matter was closed: it stays closed, and says so.
    public var mailsSinceClosed: [Entry] {
        guard let closed = matter.closedAt else { return [] }
        return entries.filter { ($0.date ?? .distantPast) > closed }
    }
}
