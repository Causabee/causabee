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
@ModelActor
public actor StoreWorker {
    /// One worker for the store: what it does is done one after another.
    @MainActor private static var workers: [ObjectIdentifier: StoreWorker] = [:]

    @MainActor
    public static func `for`(_ container: ModelContainer) -> StoreWorker {
        let key = ObjectIdentifier(container)
        if let known = workers[key] { return known }
        let made = StoreWorker(modelContainer: container)
        workers[key] = made
        return made
    }

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

    /// Left out on this device: said in the store, for every device.
    public func setAside(_ ids: Set<String>, device: String) {
        SortedMails.setAside(ids, device: device, in: modelContext)
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
