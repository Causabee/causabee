import Foundation
import SwiftData

/// The store's work away from the screen. A mail check, a Calendar sync, Auto's look for what
/// changed: each read every mail's record, every answer, every matter — on the main thread, where
/// the screen is drawn, and the screen stood still while they did (a third of a second, measured).
/// Here they read with a context of their own, on a thread of their own, and hand back only
/// what was found: ids, addresses, answers — never the store's objects, which belong to the
/// context that read them.
///
/// It reads; what it would change on something the screen shows, it says, and the screen's
/// context puts it down — a few values, by id. Saved here, a change did not reach the objects the
/// screen already holds. New records, which no screen holds yet, it may save itself.
public actor StoreWorker {
    private let container: ModelContainer
    /// Its own context, made on first use inside the worker — on one of its threads, not the
    /// main one. (A SwiftData `@ModelActor` made its context where the worker was made, and a
    /// worker made from the screen's code then ran on the main thread: measured, and replaced.)
    private var made: ModelContext?
    private var modelContext: ModelContext {
        if let made { return made }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        made = context
        return context
    }

    init(container: ModelContainer) { self.container = container }

    /// One worker for the store: what it does is done one after another.
    @MainActor private static var workers: [ObjectIdentifier: StoreWorker] = [:]

    @MainActor
    public static func `for`(_ container: ModelContainer) async -> StoreWorker {
        let key = ObjectIdentifier(container)
        if let known = workers[key] { return known }
        let made = StoreWorker(container: container)
        workers[key] = made
        return made
    }

    /// Whether its work runs away from the main thread, as it must.
    public func isAwayFromScreen() -> Bool { !Thread.isMainThread }

    // MARK: Mail

    /// What a mail check has to know before it looks: what is sorted, where, and by whom.
    public struct MailKnown: Sendable {
        /// The answers any device put in the store, by Message-ID.
        public var answered: [String: Judgement] = [:]
        /// Left out on any device.
        public var setAside: Set<String> = []
        /// Mail in a matter: sorted somewhere, whatever the record says.
        public var inMatters: Set<String> = []
        /// The people of the matters, by address: their new mail is offered without a label.
        public var knownSenders: [String] = []
        /// Drafts opened from a matter: their mail, once sent, goes into that matter.
        public var sentDrafts: [LabelIntake.SentDraft] = []
        /// Some matter holds mail: sorted somewhere before.
        public var hasMail = false
    }

    /// All of it at once — and what this device left out put in the store first, for the others.
    public func mailKnown(leftOutHere: Set<String>, device: String) -> MailKnown {
        SortedMails.setAside(leftOutHere, device: device, in: modelContext)
        var known = MailKnown()
        known.answered = SortedMails.answered(in: modelContext)
        known.setAside = SortedMails.setAside(in: modelContext)
        let entries = (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []
        known.inMatters = Set(entries.map(\.messageID)).subtracting([""])
        known.hasMail = entries.contains { $0.source.kind == .mail }
        known.knownSenders = KnownSenders.addresses(in: (try? modelContext.fetch(FetchDescriptor<Matter>())) ?? [])
        known.sentDrafts = LabelIntake.SentDraft.recent(in: modelContext)
        return known
    }

    /// Every mail some device has dealt with: sorted, bulk, in a matter, or left out.
    public func dealtWith() -> Set<String> { SortedMails.known(in: modelContext) }

    /// The mails sorted somewhere or in a matter — what another device settled meanwhile.
    public func settled() -> Set<String> {
        SortedMails.answeredIDs(in: modelContext)
            .union(((try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []).map(\.messageID))
            .subtracting([""])
    }

    /// Left out on any device.
    public func setAside() -> Set<String> { SortedMails.setAside(in: modelContext) }

    /// Mail read but in no matter, to put into one — every answer and every mail of the store read
    /// for it, some thirty milliseconds with two thousand.
    public func unplaced(log: URL, setAsideHere: Set<String>) -> [Judgement] {
        Unplaced.find(log: log, context: modelContext, setAside: setAsideHere.union(SortedMails.setAside(in: modelContext)))
    }

    /// Left out on this device: said in the store, for every device.
    public func setAside(_ ids: Set<String>, device: String) {
        SortedMails.setAside(ids, device: device, in: modelContext)
    }

    /// The names the other devices' lists know, into this device's own list: every list read
    /// and its names learned — a tenth of a second on the main thread before each check.
    @discardableResult
    public func adoptNames(into url: URL, device: String) throws -> Int {
        try NameLists.adopt(into: url, device: device, in: modelContext)
    }

    /// The kept words of every mail and file, both ways between this device and the store: every
    /// mail's id and every kept text read, and a file looked for each — on the worker.
    @discardableResult
    public func shareKeptTexts(besides store: URL) -> (up: Int, down: Int) {
        KeptTexts.share(besides: store, in: modelContext)
    }

    // MARK: Matters

    /// The overview of these matters, prepared from the store as it is saved.
    public func overviewPage(ids: [PersistentIdentifier], now: Date) -> OverviewPage {
        let all = (try? modelContext.fetch(FetchDescriptor<Matter>())) ?? []
        let byID = Dictionary(all.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        return OverviewPage(ids.compactMap { byID[$0] }, today: now)
    }

    /// Each open matter's record as one short word, by its key — what Auto looks at to see that
    /// one has changed. Every mail, file and task of every matter is read for it: here, not on
    /// the screen's thread, after every save.
    public func recordStamps() -> [String: String] {
        var stamps: [String: String] = [:]
        for matter in (try? modelContext.fetch(FetchDescriptor<Matter>())) ?? [] where !matter.isClosed {
            stamps[matter.key] = matter.recordStamp
        }
        return stamps
    }

    // MARK: Unread mail

    /// The mails whose unread dot a check asks about: from the mailbox, from the last year — of
    /// every matter, or of the one with this key.
    public func unreadAsked(matter key: String? = nil, now: Date = Date()) -> [(pointer: String, messageID: String)] {
        let since = now.addingTimeInterval(-365 * 86_400)
        let entries: [Entry]
        if let key {
            let matters = (try? modelContext.fetch(FetchDescriptor<Matter>(predicate: #Predicate { $0.key == key }))) ?? []
            entries = matters.flatMap { $0.entries ?? [] }
        } else {
            entries = (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []
        }
        return entries.filter {
            $0.source.kind == .mail && $0.source.pointer.hasPrefix("imap://") && !$0.messageID.isEmpty && ($0.date ?? .distantPast) > since
        }.map { (pointer: $0.source.pointer, messageID: $0.messageID) }
    }

    /// Of what the mailbox said, what differs from the store: the dots to change.
    public func unreadChanges(_ unread: [String: Bool]) -> [String: Bool] {
        guard !unread.isEmpty else { return [:] }
        var changes: [String: Bool] = [:]
        for entry in (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? [] {
            if let now = unread[entry.messageID], entry.isUnread != now { changes[entry.messageID] = now }
        }
        return changes
    }
}
