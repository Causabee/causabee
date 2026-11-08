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

    /// The matter's newest mail: what its day in the overview's journal says.
    public struct Latest: Equatable, Sendable {
        public let title: String
        public let digest: String?
        /// Who wrote it, by name where the mail gives one.
        public let from: String?
        public let date: Date
        /// How many mails came that day.
        public let mails: Int
        /// How many files came that day. Only for a matter recent enough to be in the journal.
        public let files: Int
        /// What it was: a mail, a file, a chat.
        public var kind: Source.Kind = .mail
        /// The mail itself: what the card opens at when it says what the mail says.
        public var entry: PersistentIdentifier? = nil
        /// Made in the matter, newer than any mail: a note, a task added, a task done — whoever
        /// made it. Nil: the mail or the file itself.
        public var made: Made? = nil
        public enum Made: Equatable, Sendable { case note, savedAnswer, taskAdded, taskDone }
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
    /// Of those, the ones the owner has not ignored: what the overview shows.
    public let mailsToShowSinceClosed: Int
    public let lastDate: Date?
    /// Its first mail's day: "since …" under its name.
    public let firstDate: Date?
    public let dated: [Dated]
    /// What new mail changes, as the brief says, until the owner has seen it: its first line. It
    /// lights the dot and the card's "NEW".
    public let news: String?
    /// The same first line, seen or not: once the matter was opened its words stay on the card,
    /// only "NEW" goes (9 November).
    public let newsLine: String?
    /// What is new on its Digest, the first two as lines — "New task: …", "Date Nov 26: …" — and
    /// how many there are: what the overview says happened, until it is seen.
    public let fresh: [String]
    public let newCount: Int
    public let latest: Latest?
    /// What is next for the owner: Causabee's step while nothing has changed since it was written,
    /// else the one worked out on the device — the card's main line (8 November: a task ticked off
    /// three days before was all a card said, while a step waited).
    public let step: String?

    public var isPinned: Bool { pinnedAt != nil }
    /// Something going on: an open task, or a day ahead.
    public var isActive: Bool { !isClosed && (openCount > 0 || next != nil) }

    /// `quick`: without reading every mail's date — for the first drawing after Causabee starts,
    /// while the worker reads them: the dates come with the page it prepares.
    /// `filed`: when each mail was sorted in, by Message-ID — a mail filed long after it was written
    /// happened here the day it was filed.
    public init(_ matter: Matter, today: String, quick: Bool = false, filed: [String: Date] = [:]) {
        id = matter.persistentModelID
        key = matter.key
        name = matter.name
        icon = matter.shownIcon
        isClosed = matter.isClosed
        pinnedAt = matter.pinnedAt
        closedAt = matter.closedAt
        // Each relationship read once, here.
        let open = matter.openTodos
        let deadlines = (matter.deadlines ?? []).shown
        let appointments = (matter.appointments ?? []).shown
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
        let dates = quick ? [] : MailDates.of(matter, entries: entries)
        lastDate = dates.last
        firstDate = dates.first
        let closed = matter.closedAt
        let after = { (day: Date) in dates.count - (dates.firstIndex { $0 > day } ?? dates.count) }
        newMailsSinceClosed = closed.map(after) ?? 0
        mailsToShowSinceClosed = closed.map { after(max($0, matter.ignoredMailUntil ?? $0)) } ?? 0
        news = matter.brief == nil ? nil : matter.shownBrief?.news.flatMap { $0.seen ? nil : $0.lines.first }
        newsLine = matter.brief == nil ? nil : matter.shownBrief?.news?.lines.first
        let new = quick ? [] : matter.newItems()
        newCount = new.count
        // Something to do or a day first; what is only good to know after them.
        let ordered = new.filter { if case .fact = $0 { false } else { true } } + new.filter { if case .fact = $0 { true } else { false } }
        fresh = ordered.prefix(2).map(Self.line)
        let written = matter.nextStep != nil && matter.nextStepAt.map { (matter.lastChange ?? .distantPast) <= $0 } == true
        step = written ? matter.nextStep
            : quick ? nil : MatterStatus(matter, today: MatterStatus.date(of: today) ?? Date()).nextStep?.text
        var mail: Latest?
        // A file, a scan, a chat stands on the page as its file, not as a mail: the card opens
        // at the file (7 November: a file's card landed nowhere).
        func shown(_ entry: Entry) -> PersistentIdentifier {
            let file = entry.source.kind == .mail ? nil
                : (matter.documents ?? []).first { !$0.isHidden && ($0.messageID == entry.messageID
                    || (!entry.source.pointer.isEmpty && $0.source.pointer == entry.source.pointer)) }
            return file?.persistentModelID ?? entry.persistentModelID
        }
        func from(_ entry: Entry) -> String? { Email.displayName(in: entry.from) ?? Email.address(in: entry.from).nilIfEmpty }
        if let last = dates.last, let newest = entries.first(where: { $0.date == last }) {
            let onLast = MailDates.onLastDay(of: matter, entries: entries)
            let files = Date().timeIntervalSince(last) > 15 * 86_400 ? 0
                : (matter.documents ?? []).filter { onLast.ids.contains($0.messageID) && !$0.isHidden && !$0.isSmallImage }.count
            mail = Latest(title: newest.title, digest: newest.digest, from: from(newest),
                          date: last, mails: onLast.mails, files: files, kind: newest.source.kind, entry: shown(newest))
        }
        // Filed later than it was written: the day it was filed is when it happened here (8 November:
        // a mail written earlier, filed today, stood under yesterday's task).
        if !quick, let (entry, at) = entries.compactMap({ entry in filed[entry.messageID].map { (entry, $0) } }).max(by: { $0.1 < $1.1 }),
           at > (mail?.date ?? .distantPast) {
            mail = Latest(title: entry.title, digest: entry.digest, from: from(entry),
                          date: at, mails: 1, files: 0, kind: entry.source.kind, entry: shown(entry))
        }
        // What happened last is the latest, whoever did it: a mail, a file, a note, a task added or
        // done (7 November: "it is not clear to me when what appears" — a note or a task of the
        // owner's own stood under yesterday's mail). A task from a mail has the mail's date: the
        // mail stays the latest for it.
        var made: [Latest] = []
        func add(_ text: String, _ date: Date?, _ id: PersistentIdentifier, _ kind: Latest.Made) {
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let date, !text.isEmpty else { return }
            made.append(Latest(title: text, digest: nil, from: nil, date: date, mails: 0, files: 0, kind: .conversation,
                               entry: id, made: kind))
        }
        for note in (matter.noteBlocks ?? []).shown { add(note.text, note.createdAt, note.persistentModelID, note.fromAssistant ? .savedAnswer : .note) }
        for todo in (matter.todos ?? []).shown {
            if todo.isDone { add(todo.text, todo.doneAt, todo.persistentModelID, .taskDone) }
            else { add(todo.text, todo.createdAt, todo.persistentModelID, .taskAdded) }
        }
        let newestMade = made.max { $0.date < $1.date }
        if let newestMade, newestMade.date > (mail?.date ?? .distantPast) { latest = newestMade } else { latest = mail }
    }
}

extension MatterSummary {
    /// One new thing in a line of its own: "New task: Book a parking permit".
    static func line(_ item: NewItem) -> String {
        switch item {
        case .task(let todo): "New task: " + todo.text
        case .fact(let todo): "Good to know: " + todo.text
        case .appointment(let date): "Date \(MatterStatus.short(date.day)): " + date.what
        case .deadline(let date): "Deadline \(MatterStatus.short(date.day)): " + date.what
        }
    }

    /// The card's small line over what happened: who it came from, or what it was when no one
    /// wrote it — a file, a chat, a note.
    public var who: String? {
        guard let latest else { return nil }
        // Something new not yet seen is what the card says, under its "NEW": not the owner's own step.
        if isNew, latest.made != nil { return nil }
        switch latest.made {
        case .note: return "Your note"
        case .savedAnswer: return "Saved from chat"
        case .taskAdded: return "Task added"
        case .taskDone: return "Done"
        case nil: break
        }
        switch latest.kind {
        case .mail: return latest.from
        case .document, .photo, .screenshot: return "File"
        case .conversation: return "Chat"
        case .spokenNote: return "Note"
        case .phoneCall: return "Call"
        }
    }

    /// What it was, at a glance: the symbol before who (7 November: a mail was known only by its subject).
    public var symbol: String? {
        guard let latest else { return nil }
        if isNew, latest.made != nil { return nil }
        switch latest.made {
        case .note: return "note.text"
        case .savedAnswer: return "sparkles"
        case .taskAdded: return "plus.circle"
        case .taskDone: return "checkmark.circle"
        case nil: break
        }
        switch latest.kind {
        case .mail: return "envelope"
        case .document: return "doc"
        case .photo, .screenshot: return "photo"
        case .conversation: return "bubble.left"
        case .spokenNote: return "waveform"
        case .phoneCall: return "phone"
        }
    }

    /// What happened, in plain words: the news, what is new, else what the newest mail says —
    /// its summary's first sentence, or its subject without "AW:", "Fwd:" and "Chat:" (7 November:
    /// "dokument · Boka tid för" said nothing).
    public var what: String? {
        // What is new comes first while it is unseen: the card's "NEW" stands over it.
        if let news { return news }
        if !fresh.isEmpty { return fresh.joined(separator: " · ") }
        if latest?.made != nil { return latest?.title }
        if let newsLine { return newsLine }
        guard let latest else { return nil }
        if let digest = latest.digest?.trimmingCharacters(in: .whitespacesAndNewlines), !digest.isEmpty {
            if let sentence = Self.firstSentence(digest) { return sentence }
        }
        return Self.subject(latest.title)
    }

    /// Whether the card says the news or what is new: then it opens there, at the top of the Digest;
    /// else at the mail it tells of.
    public var tellsNew: Bool { isNew }

    /// Something new not yet seen: the yellow dot in the sidebar and the overview's rows, and
    /// "NEW" on the cards — one signal, on together and off together. Opening the matter sees it.
    public var isNew: Bool { news != nil || newCount > 0 }

    /// What comes next, for the card's foot: "Next: Nov 10 · Call the insurer".
    public var ahead: String? {
        // The step over it says the same thing: then only its day.
        next.map { next in
            let same = step.map { Self.plain($0) == Self.plain(next.what) } ?? false
            return same ? "Due \(MatterStatus.short(next.day))" : "Next: \(MatterStatus.short(next.day)) · \(next.what)"
        }
    }

    private static func plain(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    /// The first sentence that says something: a greeting, thanks or "we look forward" is passed
    /// over (8 November: "Wir freuen uns sehr auf die zukünftige Zusammenarbeit" was all a card
    /// said). A sentence with a number in it is kept — "Thank you for the €120" says something.
    static func firstSentence(_ text: String) -> String? {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            guard let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty else { return }
            // "ab 1. Januar": a German date is no sentence's end.
            if let last = sentences.last, last.range(of: #"\b\d{1,2}\.$"#, options: .regularExpression) != nil {
                sentences[sentences.count - 1] = last + " " + sentence
            } else {
                sentences.append(sentence)
            }
        }
        return sentences.first { !isPleasantry($0) }
    }

    static func isPleasantry(_ sentence: String) -> Bool {
        guard sentence.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
        let pattern = #"^(wir freuen uns|ich freue mich|freuen uns|vielen dank|herzlichen dank|danke|besten dank|herzlich willkommen|willkommen|schön, dass|mit freundlichen|beste grüße|viele grüße|liebe grüße|wir hoffen|ich hoffe|thank|thanks|many thanks|we look forward|looking forward|we are (delighted|pleased|happy)|welcome|kind regards|best regards|we hope|i hope)\b"#
        return sentence.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// A subject without the prefixes mail and chats put before it.
    static func subject(_ title: String) -> String {
        let cleaned = title.replacingOccurrences(of: #"^\s*((re|aw|wg|fw|fwd|sv|vs|tr|weiterleitung|chat)\s*:\s*)+"#,
                                                 with: "", options: [.regularExpression, .caseInsensitive])
        return cleaned.isEmpty ? title : cleaned
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
    /// The journal across all matters: the open ones with mail in the last two weeks, the newest first.
    public let recent: [MatterSummary]
    private let byID: [PersistentIdentifier: MatterSummary]

    public init(_ matters: [Matter], today: Date = Date(), quick: Bool = false) {
        let day = MatterStatus.day(today)
        self.today = day
        // When each mail was filed: one look for all matters, its words left unread.
        var filed: [String: Date] = [:]
        if !quick, let context = matters.first?.modelContext {
            var descriptor = FetchDescriptor<SortedMail>()
            descriptor.propertiesToFetch = [\.messageID, \.sortedAt]
            for record in (try? context.fetch(descriptor)) ?? [] where !record.messageID.isEmpty {
                filed[record.messageID] = max(filed[record.messageID] ?? .distantPast, record.sortedAt)
            }
        }
        let summaries = matters.map { MatterSummary($0, today: day, quick: quick, filed: filed) }
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
        let limit = today.addingTimeInterval(-14 * 86_400)
        recent = summaries.filter { !$0.isClosed && ($0.latest?.date ?? .distantPast) >= limit }
            .sorted { ($0.latest?.date ?? .distantPast) > ($1.latest?.date ?? .distantPast) }
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
        // The first page, as Causabee starts: drawn at once without every mail's date — reading
        // them was most of half a second on the main thread before anything showed — and the
        // whole page from the worker a moment later.
        if let worker, !kept.contains(where: { $0.ids == ids }) {
            let page = OverviewPage(matters, today: now, quick: true)
            keep(page, version: version - 1, day: day, ids: ids)
            ask(worker, ids: ids, version: version, day: day, now: now)
            _ = arrived
            return page
        }
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

    /// After a change: every set of matters asked about lately, prepared anew by the worker.
    public func refresh(version: Int) {
        guard let worker else { return }
        let day = MatterStatus.day(Date())
        var seen: Set<[PersistentIdentifier]> = []
        for page in kept.reversed() where page.day == day && page.version < version && seen.insert(page.ids).inserted {
            ask(worker, ids: page.ids, version: version, day: day, now: Date())
        }
    }

    /// Forgets the pages: the next one asked for is prepared anew.
    public func forget() { kept = []; single = (-1, "", [:]); asked = [] }
}

/// Each matter's mail dates, in order, kept until its number of mails changes: a mail keeps its
/// day, and reading every mail's date of every matter — thousands — was most of preparing the
/// overview again after any change at all, a task ticked or a brief written.
enum MailDates {
    /// The newest day's mails, and the Message-IDs of all that came that day: a file comes by those.
    typealias LastDay = (mails: Int, ids: Set<String>)
    private typealias Kept = (count: Int, dates: [Date], lastDay: LastDay)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var kept: [PersistentIdentifier: Kept] = [:]

    private static func kept(_ matter: Matter, entries: [Entry]) -> Kept {
        let id = matter.persistentModelID
        lock.lock()
        let known = kept[id]
        lock.unlock()
        if let known, known.count == entries.count { return known }
        let dated = entries.filter { $0.date != nil }
        let dates = dated.compactMap(\.date).sorted()
        let newest = dates.last.map(MatterStatus.day)
        let onLast = dated.filter { $0.date.map(MatterStatus.day) == newest }
        let fresh: Kept = (entries.count, dates, (onLast.filter { $0.source.kind == .mail }.count, Set(onLast.map(\.messageID))))
        lock.lock()
        kept[id] = fresh
        lock.unlock()
        return fresh
    }

    static func of(_ matter: Matter, entries: [Entry]) -> [Date] { kept(matter, entries: entries).dates }

    static func onLastDay(of matter: Matter, entries: [Entry]) -> LastDay { kept(matter, entries: entries).lastDay }
}
