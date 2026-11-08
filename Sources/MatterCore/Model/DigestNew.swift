import Foundation
import SwiftData

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

    /// When it came: what it is ordered by, newest first.
    var came: Date {
        switch self {
        case .task(let item), .fact(let item): item.createdAt
        case .appointment(let item): item.sources.first?.date ?? .distantPast
        case .deadline(let item): item.sources.first?.date ?? .distantPast
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

    /// What is new, newest first: open tasks and facts made since, and dates whose mail came since —
    /// from mail, a file or Pro, not what the owner added by hand. Hidden, done or past: not new.
    public func newItems(now: Date = Date()) -> [NewItem] {
        guard !isClosed else { return [] }
        let since = newSince(now: now)
        let today = MatterStatus.day(now)
        let kept = Set(shownBrief?.newKept ?? [])
        func brought(_ sources: [Source]) -> Bool { sources.contains { $0.kind != .conversation } }
        var items: [NewItem] = []
        for todo in (todos ?? []) where !todo.isHidden && !todo.isDone && todo.createdAt > since {
            if todo.isInfo {
                if todo.isFact || brought(todo.sources) { items.append(.fact(todo)) }
            } else if brought(todo.sources) {
                items.append(.task(todo))
            }
        }
        for item in (appointments ?? []) where !item.isHidden && item.day >= today && brought(item.sources)
            && (item.sources.first?.date ?? .distantPast) > since {
            items.append(.appointment(item))
        }
        for item in (deadlines ?? []) where !item.isHidden && item.day >= today && brought(item.sources)
            && (item.sources.first?.date ?? .distantPast) > since {
            items.append(.deadline(item))
        }
        return items.filter { !kept.contains($0.key) }.sorted { $0.came > $1.came }
    }

    /// ✓ on one new thing: kept as it is, and not new any more — the rest stays new.
    public func keepNew(_ item: NewItem) {
        var brief = shownBrief ?? Brief()
        guard !brief.newKept.contains(item.key) else { return }
        brief.newKept = Array((brief.newKept + [item.key]).suffix(200))
        shownBrief = brief
    }

    /// Opened: what is new has been looked at — the dot goes, and next time the card says it
    /// without "NEW". Whether there was anything, for the card to still say "NEW" this once.
    @discardableResult
    public func openedNew(at now: Date = Date()) -> Bool {
        let unseen = shownBrief?.news?.seen == false || !newItems().isEmpty
        if unseen { sawNew(at: now) }
        return unseen
    }

    /// "Seen": what is new now is not new any more, and the news with it.
    public func sawNew(at now: Date = Date()) {
        var brief = shownBrief ?? Brief()
        brief.newSeenAt = now
        brief.newKept = []
        brief.news?.seen = true
        shownBrief = brief
    }
}
