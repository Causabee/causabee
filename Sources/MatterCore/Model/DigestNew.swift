import Foundation
import SwiftData
import Synchronization

/// What is new on a matter's Digest: the tasks, dates and facts that mail, files and Pro brought
/// since the owner last said "Seen" — checked there, where the owner looks every day, not in Plan.
public enum NewItem: Identifiable {
    case task(Todo), fact(Todo), appointment(Appointment), deadline(Deadline)

    public var id: PersistentIdentifier {
        switch self {
        case .task(let item), .fact(let item): item.persistentModelID
        case .appointment(let item): item.persistentModelID
        case .deadline(let item): item.persistentModelID
        }
    }

    /// The same thing on every device: what it is made of, not its id here.
    public var key: String {
        switch self {
        case .task(let item), .fact(let item): "t|" + (item.origin.isEmpty ? item.text : item.origin)
        case .appointment(let item): "a|" + (item.sources.first?.messageID ?? "") + "|" + item.day + "|" + item.what
        case .deadline(let item): "d|" + (item.sources.first?.messageID ?? "") + "|" + item.day + "|" + item.what
        }
    }

    /// Where it came from, for its line: the first mail or file.
    public var source: Source? {
        switch self {
        case .task(let item): item.sources.first
        case .fact(let item): item.factSources.first
        case .appointment(let item): item.sources.first
        case .deadline(let item): item.sources.first
        }
    }
}

/// Every arrival in a store, read once and kept until another comes in: the overview asks for every
/// matter, and one fetch per matter cost a frame.
enum Arrivals {
    /// The store it was read from — held weakly, so a new store at the same address is not taken
    /// for it — how many there were, and when each came.
    private final class Kept {
        weak var context: ModelContext?
        let count: Int
        let map: [String: Date]
        init(_ context: ModelContext, _ count: Int, _ map: [String: Date]) { self.context = context; self.count = count; self.map = map }
    }
    nonisolated(unsafe) private static var kept: [ObjectIdentifier: Kept] = [:]
    private static let lock = NSLock()

    static func all(in context: ModelContext) -> [String: Date] {
        let key = ObjectIdentifier(context)
        let count = (try? context.fetchCount(FetchDescriptor<SortedMail>())) ?? 0
        if let hit = lock.withLock({ kept[key] }), hit.context === context, hit.count == count { return hit.map }
        var map: [String: Date] = [:]
        for record in (try? context.fetch(FetchDescriptor<SortedMail>())) ?? [] {
            map[record.messageID] = min(map[record.messageID] ?? record.sortedAt, record.sortedAt)
        }
        lock.withLock {
            kept = kept.filter { $0.value.context != nil }
            kept[key] = Kept(context, count, map)
        }
        return map
    }
}

extension Matter {
    /// When each thing that came in reached the bee, by its id: the moment it was sorted in, on
    /// whichever device — not the date written on it. A screenshot taken weeks ago, an old PDF, a
    /// mail filed late arrive today, and are new today (manifesto 1 and 2).
    public func arrivals() -> [String: Date] {
        guard let context = modelContext else { return [:] }
        return Arrivals.all(in: context)
    }

    /// When a source reached the bee: its arrival, else the date on it.
    static func arrived(_ source: Source, _ arrivals: [String: Date]) -> Date? {
        source.messageID.flatMap { arrivals[$0] } ?? source.date
    }

    /// When a new thing came: when what it rests on arrived. A fact the bee writes again in other
    /// words is rebuilt today but rests on what came on its day — new only when that is
    /// (9 November: facts from 27 October came back as NEW every morning).
    static func came(_ item: NewItem, _ arrivals: [String: Date]) -> Date {
        switch item {
        case .task(let todo), .fact(let todo):
            let dates = (todo.isFact ? todo.factSources : todo.sources).filter { $0.kind != .conversation }.compactMap { arrived($0, arrivals) }
            return dates.max() ?? todo.createdAt
        case .appointment(let date): return date.sources.first.flatMap { arrived($0, arrivals) } ?? .distantPast
        case .deadline(let date): return date.sources.first.flatMap { arrived($0, arrivals) } ?? .distantPast
        }
    }
}

extension Matter {
    /// With nothing seen yet, what came in the last three days is new — not the whole matter.
    static let firstLook: TimeInterval = 3 * 24 * 3600

    /// Since when things are new: the last "Seen".
    public func newSince(now: Date = Date()) -> Date {
        shownBrief?.newSeenAt ?? now.addingTimeInterval(-Self.firstLook)
    }

    /// What is new, newest first: open tasks and facts, and dates, from what came in since —
    /// mail, a screenshot, a photo, a scan, a file, Pro — not what the owner added by hand.
    /// Hidden, done or past: not new.
    public func newItems(now: Date = Date()) -> [NewItem] { dated(now: now).map(\.item) }

    /// What is new, each with when it came.
    func dated(now: Date = Date()) -> [(item: NewItem, came: Date)] {
        guard !isClosed else { return [] }
        let since = newSince(now: now)
        let today = MatterStatus.day(now)
        let kept = Set(shownBrief?.newKept ?? [])
        let arrivals = arrivals()
        func brought(_ sources: [Source]) -> Bool { sources.contains { $0.kind != .conversation } }
        var items: [NewItem] = []
        for todo in (todos ?? []) where !todo.isHidden && !todo.isDone {
            if todo.isInfo {
                // A fact that rests only on the owner's own word — a note, what they said — is
                // theirs: never shown back to them as new.
                if brought(todo.isFact ? todo.factSources : todo.sources) { items.append(.fact(todo)) }
            } else if brought(todo.sources) {
                items.append(.task(todo))
            }
        }
        for item in (appointments ?? []) where !item.isHidden && item.day >= today && brought(item.sources) { items.append(.appointment(item)) }
        for item in (deadlines ?? []) where !item.isHidden && item.day >= today && brought(item.sources) { items.append(.deadline(item)) }
        return items.filter { !kept.contains($0.key) }
            .map { (item: $0, came: Self.came($0, arrivals)) }
            .filter { $0.came > since }
            .sorted { $0.came > $1.came }
    }

    /// ✓ on one new thing: kept as it is, and not new any more — the rest stays new.
    public func keepNew(_ item: NewItem) {
        var brief = shownBrief ?? Brief()
        guard !brief.newKept.contains(item.key) else { return }
        brief.newKept = Array((brief.newKept + [item.key]).suffix(200))
        shownBrief = brief
    }

    /// What is new and not looked at yet: what came after the matter was last opened. It is what
    /// the yellow dot and "NEW" say — one signal. What was looked at stays on the card, unlabelled,
    /// until the owner handles it: 👍, ×, done, or "Seen".
    public func unopenedNew(now: Date = Date()) -> [NewItem] {
        let looked = shownBrief?.newLookedAt ?? .distantPast
        return dated(now: now).filter { $0.came > looked }.map(\.item)
    }

    /// Whether everything in these came before the owner last opened the matter: news about it
    /// is not new, though written after.
    public func lookedAtAll(_ entries: [Entry], _ files: [Document]) -> Bool {
        guard let looked = [shownBrief?.newLookedAt, shownBrief?.newSeenAt].compactMap({ $0 }).max() else { return false }
        let arrivals = arrivals()
        let came = entries.map { arrivals[$0.messageID] ?? $0.date ?? .distantFuture }
            + files.map { arrivals[$0.messageID] ?? $0.source.date ?? .distantFuture }
        return !came.isEmpty && came.allSatisfy { $0 <= looked }
    }

    /// The news, while it is neither seen nor opened.
    public var unopenedNews: Brief.News? {
        shownBrief?.news.flatMap { $0.seen || $0.opened == true ? nil : $0 }
    }

    /// Whether something is new that was not looked at: the dot, and "NEW".
    public func saysNew(now: Date = Date()) -> Bool {
        unopenedNews != nil || !unopenedNew(now: now).isEmpty
    }

    /// Opened: what is new has been looked at — the dot and "NEW" go; the card and its lines stay
    /// until handled. Whether there was anything, for the card to still say "NEW" this once.
    @discardableResult
    public func openedNew(at now: Date = Date()) -> Bool {
        guard saysNew(now: now) else { return false }
        var brief = shownBrief ?? Brief()
        brief.newLookedAt = now
        if brief.news?.seen == false { brief.news?.opened = true }
        shownBrief = brief
        return true
    }

    /// "Seen": what is new now is not new any more, and the news with it.
    public func sawNew(at now: Date = Date()) {
        var brief = shownBrief ?? Brief()
        brief.newSeenAt = now
        brief.newKept = []
        brief.newLookedAt = now
        brief.news?.seen = true
        shownBrief = brief
    }
}
