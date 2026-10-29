import Foundation
import Observation
import SwiftData

/// One matter as the overview, the sidebar and the week show it: plain values, worked out once
/// from the store — not read from it again by every card, row and day each time the screen draws.
public struct MatterSummary: Identifiable, Equatable, Sendable {
    public struct Overdue: Equatable, Sendable {
        public let todo: PersistentIdentifier
        public let due: String
        public let text: String
    }

    /// Something with a day on it: an open task's due day, a deadline, an appointment.
    public struct Dated: Equatable, Sendable {
        public let day: String
        public let time: String?
        public let what: String
        /// The task it is, to open its matter at it; nil for a deadline or an appointment.
        public let todo: PersistentIdentifier?
    }

    public struct Next: Equatable, Sendable {
        public let day: String
        public let what: String
    }

    public let id: PersistentIdentifier
    public let key: String
    public let name: String
    public let icon: String
    public let isClosed: Bool
    public let pinnedAt: Date?
    public let closedAt: Date?
    public let openCount: Int
    /// Open tasks by whose they are.
    public let mine: Int
    public let ours: Int
    public let waiting: Int
    public let next: Next?
    /// Open tasks past their day, the longest overdue first.
    public let overdue: [Overdue]
    public let newMailsSinceClosed: Int
    public let lastDate: Date?
    /// Its first mail's day: "since …" under its name.
    public let firstDate: Date?
    public let dated: [Dated]
    /// What new mail changes, as the brief says, until the owner has seen it: its first line.
    public let news: String?

    public var isPinned: Bool { pinnedAt != nil }
    /// Something going on: an open task, or a day ahead.
    public var isActive: Bool { !isClosed && (openCount > 0 || next != nil) }

    public init(_ matter: Matter, today: String) {
        id = matter.persistentModelID
        key = matter.key
        name = matter.name
        icon = matter.shownIcon
        isClosed = matter.isClosed
        pinnedAt = matter.pinnedAt
        closedAt = matter.closedAt
        // Each relationship read once, here.
        let open = matter.openTodos
        let deadlines = matter.deadlines ?? []
        let appointments = matter.appointments ?? []
        let entries = matter.entries ?? []
        openCount = open.count
        mine = open.filter { $0.owner == .me }.count
        ours = open.filter { $0.owner == .we }.count
        waiting = open.filter { $0.owner == .other }.count
        // The owner's own on the days; what others do waits in the matter, as the week has it.
        let own = open.filter { $0.owner != .other }
        var dated = own.compactMap { todo in todo.due.map { Dated(day: $0, time: nil, what: todo.text, todo: todo.persistentModelID) } }
        dated += deadlines.map { Dated(day: $0.day, time: nil, what: $0.what, todo: nil) }
        dated += appointments.map { Dated(day: $0.day, time: $0.time, what: $0.what, todo: nil) }
        self.dated = dated
        next = dated.filter { $0.day >= today }.min { $0.day < $1.day }.map { Next(day: $0.day, what: $0.what) }
        overdue = open.filter { !$0.isBlocked && ($0.due ?? "9999") < today }
            .map { Overdue(todo: $0.persistentModelID, due: $0.due ?? "", text: $0.text) }
            .sorted { $0.due < $1.due }
        let dates = MailDates.of(matter, entries: entries)
        lastDate = dates.last
        firstDate = dates.first
        newMailsSinceClosed = matter.closedAt.map { closed in dates.count - (dates.firstIndex { $0 > closed } ?? dates.count) } ?? 0
        news = matter.brief == nil ? nil : matter.shownBrief?.news.flatMap { $0.seen ? nil : $0.lines.first }
    }
}

/// The overview, prepared: every matter's summary, and what is worked out from all of them — which
/// are going on and in what order, the pinned, the quiet and the closed, the week, what is overdue.
/// The same on the Mac, the iPhone and the iPad; the screens only draw it.
public struct OverviewPage: Sendable {
    public let today: String
    public let summaries: [MatterSummary]
    /// Going on: late ones first, then by their next day, then by name.
    public let active: [MatterSummary]
    /// The sidebar's order: going on, then the quiet ones by their newest mail, then the closed
    /// ones, the last closed first.
    public let ordered: [MatterSummary]
    public let pinned: [MatterSummary]
    public let quiet: [MatterSummary]
    public let closed: [MatterSummary]
    private let byID: [PersistentIdentifier: MatterSummary]

    public init(_ matters: [Matter], today: Date = Date()) {
        let day = MatterStatus.day(today)
        self.today = day
        let summaries = matters.map { MatterSummary($0, today: day) }
        self.summaries = summaries
        byID = Dictionary(summaries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let active = summaries.filter(\.isActive).sorted { a, b in
            let (lateA, lateB) = (!a.overdue.isEmpty, !b.overdue.isEmpty)
            if lateA != lateB { return lateA }
            let (nextA, nextB) = (a.next?.day ?? "9999", b.next?.day ?? "9999")
            if nextA != nextB { return nextA < nextB }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        self.active = active
        let quiet = summaries.filter { !$0.isClosed && !$0.isActive }
            .sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
        let closed = summaries.filter(\.isClosed).sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
        self.closed = closed
        // A pinned one is on top already, even when it is quiet.
        self.quiet = quiet.filter { !$0.isPinned }
        ordered = active + quiet + closed
        pinned = summaries.filter { !$0.isClosed && $0.isPinned }.sorted { ($0.pinnedAt ?? .distantPast) < ($1.pinnedAt ?? .distantPast) }
    }

    public subscript(id: PersistentIdentifier) -> MatterSummary? { byID[id] }

    /// One thing on a day, from any open matter.
    public struct Thing: Equatable {
        public let matter: MatterSummary
        public let what: String
        public let time: String?
        public let todo: PersistentIdentifier?
    }

    /// What is on `day` in the open matters: appointments by their time first, then the rest,
    /// matter by matter — as `Week.things` has it.
    public func things(on day: String) -> [Thing] {
        summaries.filter { !$0.isClosed }.flatMap { matter in
            matter.dated.filter { $0.day == day }.map { Thing(matter: matter, what: $0.what, time: $0.time, todo: $0.todo) }
        }
        .sorted { ($0.time ?? "99", $0.matter.name) < ($1.time ?? "99", $1.matter.name) }
    }

    /// The first day after `day` with anything on it, and its first thing.
    public func next(after day: String) -> (day: String, thing: Thing)? {
        guard let first = summaries.filter({ !$0.isClosed }).flatMap({ $0.dated.map(\.day) }).filter({ $0 > day }).min(),
              let thing = things(on: first).first else { return nil }
        return (first, thing)
    }

    /// Every open task past its day, across the open matters, the longest overdue first.
    public var overdue: [(task: MatterSummary.Overdue, matter: MatterSummary)] {
        summaries.filter { !$0.isClosed }.flatMap { matter in matter.overdue.map { (task: $0, matter: matter) } }
            .sorted { $0.task.due < $1.task.due }
    }
}

/// The prepared overview, kept until the store changes or the day turns: however many views ask,
/// and however often the screen draws, the matters are read once per change.
///
/// After a change it is prepared by the worker, away from the screen — every matter's tasks, dates
/// and mail read, a fifth of a second on the owner's store, measured on the main thread. Until it
/// comes, the page as it was stands; then the screens draw the new one.
@MainActor
@Observable
public final class OverviewPages {
    public static let shared = OverviewPages()
    /// A few pages: for all the matters, and for the few views that ask about some of them.
    @ObservationIgnored private var kept: [(version: Int, day: String, ids: [PersistentIdentifier], page: OverviewPage)] = []
    /// Counts the pages that came from the worker: the screens that read a page draw again then.
    public private(set) var arrived = 0
    /// Who prepares a page after a change; none, and it is prepared here, at once.
    @ObservationIgnored public var worker: StoreWorker?
    @ObservationIgnored private var asked: Set<String> = []

    public init() {}

    /// `version` goes up with every change to the store — the app's count of changes.
    public func page(for matters: [Matter], version: Int, now: Date = Date()) -> OverviewPage {
        let day = MatterStatus.day(now)
        let ids = matters.map(\.persistentModelID)
        if let found = kept.first(where: { $0.version == version && $0.day == day && $0.ids == ids }) { return found.page }
        // The same matters as before, changed: the worker prepares them, and the page as it was
        // stands until then — and whoever drew it draws again when the new one comes.
        if let worker, let before = kept.last(where: { $0.day == day && $0.ids == ids && $0.version < version }) {
            _ = arrived
            ask(worker, ids: ids, version: version, day: day, now: now)
            return before.page
        }
        let started = Date()
        let page = OverviewPage(matters, today: now)
        if CommandLine.arguments.contains("--timing-tour") { NSLog("[timing] overview prepared %d ms", Int(Date().timeIntervalSince(started) * 1000)) }
        keep(page, version: version, day: day, ids: ids)
        return page
    }

    private func keep(_ page: OverviewPage, version: Int, day: String, ids: [PersistentIdentifier]) {
        // The newest for these matters only; one for each set of matters asked about.
        kept.removeAll { $0.day != day || ($0.ids == ids && $0.version <= version) }
        kept.append((version, day, ids, page))
        if kept.count > 4 { kept.removeFirst() }
    }

    private func ask(_ worker: StoreWorker, ids: [PersistentIdentifier], version: Int, day: String, now: Date) {
        let token = "\(version) \(day) \(ids.hashValue)"
        guard asked.insert(token).inserted else { return }
        Task {
            let page = await worker.overviewPage(ids: ids, now: now)
            asked.remove(token)
            // A newer one may have come meanwhile: that one stays.
            guard !kept.contains(where: { $0.ids == ids && $0.version >= version }) else { return }
            keep(page, version: version, day: day, ids: ids)
            arrived += 1
        }
    }

    /// The matters in the page's order, from its summaries back to the store's own.
    public static func matters(_ summaries: [MatterSummary], among matters: [Matter]) -> [Matter] {
        let byID = Dictionary(matters.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        return summaries.compactMap { byID[$0.id] }
    }

    /// One matter's summary, as the store is now: from a page prepared for this change, or made
    /// for it alone and kept until the next change — a card or a row asks for its own each time it draws.
    public func summary(of matter: Matter, version: Int, now: Date = Date()) -> MatterSummary {
        let day = MatterStatus.day(now)
        let id = matter.persistentModelID
        for page in kept where page.version == version && page.day == day {
            if let found = page.page[id] { return found }
        }
        // Changed, and the worker prepares it: the newest page's summary stands until then.
        if let worker, let before = kept.filter({ $0.day == day && $0.version < version && $0.page[id] != nil }).max(by: { $0.version < $1.version }),
           let found = before.page[id] {
            _ = arrived
            ask(worker, ids: before.ids, version: version, day: day, now: now)
            return found
        }
        if single.version == version, single.day == day, let found = single.byID[id] { return found }
        if single.version != version || single.day != day { single = (version, day, [:]) }
        let made = MatterSummary(matter, today: day)
        single.byID[id] = made
        return made
    }

    @ObservationIgnored private var single: (version: Int, day: String, byID: [PersistentIdentifier: MatterSummary]) = (-1, "", [:])

    /// Forgets the pages: the next one asked for is prepared anew.
    public func forget() { kept = []; single = (-1, "", [:]); asked = [] }
}

/// Each matter's mail dates, in order, kept until its number of mails changes: a mail keeps its
/// day, and reading every mail's date of every matter — thousands — was most of preparing the
/// overview again after any change at all, a task ticked or a brief written.
enum MailDates {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var kept: [PersistentIdentifier: (count: Int, dates: [Date])] = [:]

    static func of(_ matter: Matter, entries: [Entry]) -> [Date] {
        let id = matter.persistentModelID
        lock.lock()
        let known = kept[id]
        lock.unlock()
        if let known, known.count == entries.count { return known.dates }
        let dates = entries.compactMap(\.date).sorted()
        lock.lock()
        kept[id] = (entries.count, dates)
        lock.unlock()
        return dates
    }
}
