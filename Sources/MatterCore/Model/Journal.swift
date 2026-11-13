import Foundation
import SwiftData

/// A matter as one journal: what happened, newest first, a day at a time, and what is ahead as one
/// plan — the same on every device; the screens only draw what this hands them.
public enum Journal {
    /// The filters over the journal.
    public enum Part: String, CaseIterable, Sendable {
        case all, plan, mail, files, people, notes

        public var label: String {
            switch self {
            case .all: "Digest"
            case .plan: "Plan"
            case .mail: "Mail"
            case .files: "Files"
            case .people: "People"
            case .notes: "Notes"
            }
        }

        /// What `--part` says on the command line, by the part's name or by the name it had before.
        public init?(asked: String) {
            switch asked {
            case "todo": self = .plan
            case "record": self = .all
            default: self.init(rawValue: asked)
            }
        }
    }

    /// A matter opens on its digest, however much is open: the next step lives there and nowhere
    /// else, and the plan is one tap away. A busy matter opened on its plan once, and its next step
    /// was not on the page (5 November).
    public static func opening(_ matter: Matter, today: String) -> Part { .all }

    /// The filters that have something behind them, and the one that is open whatever it has: a
    /// new matter does not look empty, and a part does not go away under the owner's hand.
    public static func parts(of matter: Matter, open: Part) -> [Part] {
        Part.allCases.filter { part in
            switch part {
            case .all: true
            case _ where part == open: true
            case .plan: !(matter.todos ?? []).shown.filter { !$0.isInfo }.isEmpty || !(matter.appointments ?? []).shown.isEmpty || !(matter.deadlines ?? []).shown.isEmpty
            case .mail: !(matter.entries ?? []).isEmpty
            case .files: !(matter.documents ?? []).filter { !$0.isHidden }.isEmpty || !(matter.links ?? []).shown.filter(\.isKept).isEmpty
            case .people: !(matter.memberships ?? []).shown.isEmpty
            case .notes: !(matter.noteBlocks ?? []).shown.isEmpty || matter.earlierNote != nil || !(matter.decisions ?? []).isEmpty
            }
        }
    }

    // MARK: The plan

    /// What is left, by when: dates and tasks in one list, a day at a time.
    public struct Plan {
        public enum Item: Identifiable {
            case task(Todo)
            case appointment(Appointment)
            case deadline(Deadline)

            public var id: PersistentIdentifier {
                switch self {
                case .task(let todo): todo.persistentModelID
                case .appointment(let appointment): appointment.persistentModelID
                case .deadline(let deadline): deadline.persistentModelID
                }
            }

            public var day: String {
                switch self {
                case .task(let todo): todo.due ?? ""
                case .appointment(let appointment): appointment.day
                case .deadline(let deadline): deadline.day
                }
            }

            var time: String {
                switch self {
                case .task(let todo): todo.dueTime ?? ""
                case .appointment(let appointment): appointment.time ?? ""
                case .deadline: ""
                }
            }

            var name: String {
                switch self {
                case .task(let todo): todo.text
                case .appointment(let appointment): appointment.what
                case .deadline(let deadline): deadline.what
                }
            }

            /// On one day: the dates first, what the day is planned around, then the tasks; each
            /// what has no hour, then by the hour.
            static func sameDay(_ a: Item, _ b: Item) -> Bool {
                func rank(_ item: Item) -> Int { if case .task = item { 1 } else { 0 } }
                if rank(a) != rank(b) { return rank(a) < rank(b) }
                if a.time != b.time { return a.time < b.time }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }

        public struct Day: Identifiable {
            public var day: String
            public var items: [Item]
            public var id: String { day }
        }

        /// "This week", "Next week", then month by month.
        public struct Stretch: Identifiable {
            public var title: String
            public var days: [Day]
            public var id: String { title }
        }

        public var overdue: [Todo] = []
        public var stretches: [Stretch] = []
        /// The owner's, with no day yet.
        public var noDay: [Todo] = []
        /// Someone else's: the owner is waiting for them.
        public var waiting: [Todo] = []
        /// Someone else's with no answer by its day: back with the owner (`Planning.isBack`).
        public var noAnswer: [Todo] = []
        /// Tasks that wait for another one: they cannot be done yet.
        public var blocked: [Todo] = []
        /// Dates gone by, the latest first.
        public var past: [Item] = []
        public var done: [Todo] = []

        public var isEmpty: Bool { overdue.isEmpty && stretches.isEmpty && noDay.isEmpty && waiting.isEmpty && noAnswer.isEmpty && blocked.isEmpty && past.isEmpty && done.isEmpty }
        /// How many days, tasks and dates stand on the plan: tasks and dates left.
        public var openCount: Int { stretches.flatMap(\.days).flatMap(\.items).count + overdue.count + noDay.count + waiting.count + noAnswer.count + blocked.count }

        /// What stands in order, a day at a time: what comes on one day together, what has no day
        /// together too.
        public static func days<Thing>(of things: [Thing], on day: (Thing) -> String?) -> [(day: String?, things: [Thing])] {
            var days: [(day: String?, things: [Thing])] = []
            for thing in things {
                let on = day(thing)
                if let last = days.indices.last, days[last].day == on { days[last].things.append(thing) }
                else { days.append((on, [thing])) }
            }
            return days
        }
    }

    public static func plan(_ status: MatterStatus) -> Plan {
        var plan = Plan()
        let open = status.matter.openTodos
        plan.overdue = status.overdue.sorted { ($0.due ?? "") < ($1.due ?? "") }
        let late = Set(plan.overdue.map(\.persistentModelID))
        plan.blocked = open.filter(\.isBlocked).sorted { ($0.due ?? "9999", $0.createdAt) < ($1.due ?? "9999", $1.createdAt) }
        let theirs = open.filter { $0.owner == .other && !$0.isBlocked && !late.contains($0.persistentModelID) }
            .sorted { ($0.due ?? "9999", $0.createdAt) < ($1.due ?? "9999", $1.createdAt) }
        plan.noAnswer = theirs.filter { Planning.isBack($0, today: status.today) }
        plan.waiting = theirs.filter { !Planning.isBack($0, today: status.today) }
        let others = open.filter { $0.owner != .other && !$0.isBlocked && !late.contains($0.persistentModelID) }
        plan.noDay = others.filter { $0.due == nil }.sorted { $0.createdAt < $1.createdAt }

        var dated: [Plan.Item] = others.filter { $0.due != nil }.map(Plan.Item.task)
        dated += status.upcomingAppointments.map(Plan.Item.appointment)
        dated += status.deadlines.filter { $0.day >= status.today }.map(Plan.Item.deadline)
        let days = Dictionary(grouping: dated, by: \.day).map { day, items in
            Plan.Day(day: day, items: items.sorted(by: Plan.Item.sameDay))
        }.sorted { $0.day < $1.day }
        var stretches: [Plan.Stretch] = []
        for day in days {
            let title = stretch(of: day.day, today: status.today)
            if stretches.last?.title == title { stretches[stretches.count - 1].days.append(day) }
            else { stretches.append(Plan.Stretch(title: title, days: [day])) }
        }
        plan.stretches = stretches

        let past: [Plan.Item] = status.pastAppointments.map(Plan.Item.appointment) + status.deadlines.filter { $0.day < status.today }.map(Plan.Item.deadline)
        plan.past = past.sorted { $0.day != $1.day ? $0.day > $1.day : Plan.Item.sameDay($0, $1) }
        plan.done = status.done
        return plan
    }

    /// Which part of the plan a day stands in. The week begins on Monday.
    static func stretch(of day: String, today: String) -> String {
        guard let date = MatterStatus.date(of: day), let now = MatterStatus.date(of: today) else { return "Later" }
        let weekday = monday.component(.weekday, from: now)
        let sinceMonday = (weekday + 5) % 7
        if let start = monday.date(byAdding: .day, value: -sinceMonday, to: now),
           let next = monday.date(byAdding: .day, value: 7, to: start),
           let after = monday.date(byAdding: .day, value: 14, to: start) {
            if date < next { return "This week" }
            if date < after { return "Next week" }
        }
        return monthTitle(date, today: now)
    }

    /// What a day's tile says: "THU" and "1"; with `month`, for a day that need not be this week's,
    /// "OCT" and "1".
    public static func tile(_ day: String, month: Bool = false) -> (over: String, number: String) {
        guard let date = MatterStatus.date(of: day) else { return ("", day) }
        return ((month ? monthShort : weekdayShort).string(from: date).uppercased(), String(monday.component(.day, from: date)))
    }

    // MARK: Who has the ball

    /// What stands between a person and the owner: what they wait for from the owner, what the
    /// owner waits for from them.
    public struct Ball {
        public var waitsForYou: String?
        public var youWaitFor: String?
        public var isEmpty: Bool { waitsForYou == nil && youWaitFor == nil }
        public init() {}
    }

    /// Only what is certain enough to say: the person whose mail the next step came from waits for
    /// the owner; someone else's task, said by name or asked for in their mail, is what the owner
    /// waits for. Every other task of the owner's says nothing about anyone waiting, and a yellow
    /// line on each person would mean nothing.
    public static func ball(of party: Party, in matter: Matter) -> Ball {
        var ball = Ball()
        let next = matter.nextStepTodo.flatMap { origin in matter.openTodos.first { $0.origin == origin } }
            ?? MatterStatus(matter).nextStep?.todo.flatMap { id in matter.openTodos.first { $0.persistentModelID == id } }
        func theirs(_ todo: Todo) -> Bool {
            guard let id = todo.sources.first?.messageID, let mail = matter.entry(messageID: id) else { return false }
            return matter.writer(mail.from) === party
        }
        if let next, next.owner != .other, theirs(next) { ball.waitsForYou = next.text }
        ball.youWaitFor = matter.openTodos.filter { $0.owner == .other }
            .sorted { ($0.due ?? "9999", $0.createdAt) < ($1.due ?? "9999", $1.createdAt) }
            .first { theirs($0) || $0.text.localizedCaseInsensitiveContains(party.name) }?.text
        return ball
    }

    /// Whom a task of someone else's is waited for from, when it is certain enough to say: a person
    /// of the matter it names, else whoever wrote the mail it came from — or the mail its file came
    /// with. Nil when neither says.
    public static func whom(_ todo: Todo) -> String? {
        guard todo.owner == .other, let matter = todo.matter else { return nil }
        if let named = matter.shownParties.first(where: { !$0.name.isEmpty && todo.text.localizedCaseInsensitiveContains($0.name) }) {
            return named.name
        }
        for source in todo.sources {
            guard let id = source.messageID, !id.isEmpty, let mail = matter.entry(messageID: id), !mail.from.isEmpty else { continue }
            if let party = matter.writer(mail.from) { return party.name }
            return matter.writerName(mail.from)
        }
        return nil
    }

    // MARK: The journal

    /// A stretch of old days, folded into one card.
    public struct Fold: Identifiable {
        public var id: String
        public var title: String
        /// "31 mails · 2 files".
        public var count: String
        /// What it was about: the first few subjects.
        public var about: String
        public var isOpen: Bool
    }

    /// One line of the journal: one flat list, so that only what is near the screen need be drawn.
    public enum Line: Identifiable {
        case day(id: String, title: String)
        case item(RecordBrowse.Item)
        case note(MatterNote)
        case decision(Decision)
        case done(Todo)
        case fold(Fold)

        public var id: String {
            switch self {
            case .day(let id, _): "day \(id)"
            case .item(let item): item.id
            case .note(let note): "note \(note.persistentModelID.hashValue)"
            case .decision(let decision): "decision \(decision.persistentModelID.hashValue)"
            case .done(let todo): "done \(todo.persistentModelID.hashValue)"
            case .fold(let fold): "fold \(fold.id)"
            }
        }

        var date: Date {
            switch self {
            case .item(let item): item.date
            case .note(let note): note.createdAt
            case .decision(let decision): decision.decidedAt
            case .done(let todo): todo.doneAt ?? .distantPast
            case .day, .fold: .distantPast
            }
        }
    }

    /// The last days stand open; what is older than this folds into its month.
    public static let openDays = 30
    /// A journal this short is read whole: there is nothing to fold away.
    public static let shortEnough = 8

    /// The journal, newest first. `opened` holds the folds the owner opened.
    public static func lines(items: [RecordBrowse.Item], notes: [MatterNote] = [], decisions: [Decision] = [], done: [Todo] = [],
                             today: Date = Date(), opened: Set<String> = []) -> [Line] {
        // A note with no words — one the assistant saved empty — is no card at all.
        let notes = notes.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let all: [Line] = items.map(Line.item) + notes.map(Line.note) + decisions.map(Line.decision) + done.filter { $0.doneAt != nil }.map(Line.done)
        let ordered = all.sorted { $0.date > $1.date }
        let start = monday.startOfDay(for: today)
        let limit = monday.date(byAdding: .day, value: -openDays, to: start) ?? start
        let older = ordered.count > shortEnough ? ordered.filter { $0.date < limit } : []
        let recent = ordered.count > shortEnough ? ordered.filter { $0.date >= limit } : ordered

        var lines = withDays(recent, today: today)
        var months: [(key: String, lines: [Line])] = []
        for line in older {
            let key = line.date == .distantPast ? "none" : yearMonth.string(from: line.date)
            if months.last?.key == key { months[months.count - 1].lines.append(line) } else { months.append((key, [line])) }
        }
        for month in months {
            let isOpen = opened.contains(month.key)
            let date = month.lines.first?.date ?? .distantPast
            let partly = monday.isDate(date, equalTo: limit, toGranularity: .month) && monday.isDate(date, equalTo: recent.last?.date ?? .distantPast, toGranularity: .month)
            let title = date == .distantPast ? "Without a day" : (partly ? "Earlier in " + monthName.string(from: date) : monthTitle(date, today: today))
            lines.append(.fold(Fold(id: month.key, title: title, count: counted(month.lines), about: about(month.lines), isOpen: isOpen)))
            if isOpen { lines += withDays(month.lines, today: today) }
        }
        return lines
    }

    /// Each day's heading, then what stands under it.
    private static func withDays(_ lines: [Line], today: Date) -> [Line] {
        var result: [Line] = []
        var last = ""
        for line in lines {
            let key = line.date == .distantPast ? "none" : MatterStatus.day(line.date)
            if key != last {
                last = key
                if key != "none" { result.append(.day(id: key, title: dayTitle(line.date, today: today))) }
            }
            result.append(line)
        }
        return result
    }

    /// "TODAY · WED, SEP 30", "YESTERDAY · SEP 29", "SUNDAY · SEP 27".
    public static func dayTitle(_ date: Date, today: Date = Date()) -> String {
        let same = monday.isDate(date, equalTo: today, toGranularity: .year)
        let day = (same ? monthDay : monthDayYear).string(from: date).uppercased()
        if monday.isDate(date, inSameDayAs: today) { return "TODAY · " + weekdayShort.string(from: date).uppercased() + ", " + day }
        if let yesterday = monday.date(byAdding: .day, value: -1, to: today), monday.isDate(date, inSameDayAs: yesterday) { return "YESTERDAY · " + day }
        return weekdayLong.string(from: date).uppercased() + " · " + day
    }

    private static func counted(_ lines: [Line]) -> String {
        var mails = 0, files = 0, links = 0, notes = 0, decisions = 0
        for line in lines {
            switch line {
            case .item(.thread(let thread)): mails += thread.count
            case .item(.document): files += 1
            case .item(.link): links += 1
            case .note: notes += 1
            case .decision: decisions += 1
            default: break
            }
        }
        func say(_ count: Int, _ one: String, _ many: String) -> String? { count == 0 ? nil : "\(count) \(count == 1 ? one : many)" }
        let parts = [say(mails, "mail", "mails"), say(files, "file", "files"), say(links, "link", "links"), say(notes, "note", "notes"), say(decisions, "decision", "decisions")]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// The first few subjects of a stretch, the newest first.
    private static func about(_ lines: [Line]) -> String {
        var names: [String] = []
        for line in lines {
            switch line {
            case .item(.thread(let thread)) where !thread.subject.isEmpty: names.append(thread.subject)
            case .decision(let decision): names.append(decision.what)
            default: break
            }
            if names.count == 3 { break }
        }
        return names.joined(separator: " · ")
    }

    /// Where the fold of a mail, a file or a link is: going to it opens its fold first.
    public static func fold(of model: PersistentIdentifier, items: [RecordBrowse.Item], today: Date = Date()) -> String? {
        let start = monday.startOfDay(for: today)
        let limit = monday.date(byAdding: .day, value: -openDays, to: start) ?? start
        for item in items where item.date < limit {
            let found: Bool
            switch item {
            case .thread(let thread): found = thread.rows.contains { $0.entry.persistentModelID == model }
            case .document(let document): found = document.persistentModelID == model
            case .link(let link): found = link.persistentModelID == model
            }
            if found { return item.date == .distantPast ? "none" : yearMonth.string(from: item.date) }
        }
        return nil
    }

    /// The line a mail, a file or a link stands on: what is not near the screen is not drawn, so
    /// going to it goes to its line first.
    public static func line(of model: PersistentIdentifier, in lines: [Line], attached: [String: [Document]]) -> Line? {
        lines.first { line in
            // A note stands as a line of its own.
            if case .note(let note) = line { return note.persistentModelID == model }
            guard case .item(let item) = line else { return false }
            switch item {
            case .thread(let thread):
                return thread.rows.contains { $0.entry.persistentModelID == model }
                    || (attached[thread.id] ?? []).contains { $0.persistentModelID == model }
            case .document(let document): return document.persistentModelID == model
            case .link(let link): return link.persistentModelID == model
            }
        }
    }

    private static func monthTitle(_ date: Date, today: Date) -> String {
        monday.isDate(date, equalTo: today, toGranularity: .year) ? monthName.string(from: date) : monthYear.string(from: date)
    }

    // MARK: Reading a day

    private static let monday: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }()

    private static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
                formatter.calendar = monday
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = pattern
        return formatter
    }

    private static let weekdayShort = formatter("EEE")
    private static let monthShort = formatter("MMM")
    private static let weekdayLong = formatter("EEEE")
    private static let monthDay = formatter("MMM d")
    private static let monthDayYear = formatter("MMM d, yyyy")
    private static let monthName = formatter("LLLL")
    private static let monthYear = formatter("LLLL yyyy")
    private static let yearMonth = formatter("yyyy-MM")
}
