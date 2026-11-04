import Foundation
import SwiftData

/// Two items of a matter that belong together, as the owner said: a photo with a task, a PDF with
/// a mail, a detail with a person. Each item stays what it is; the connection only says they go
/// together, and is shown on both. Kept as two ends, each pointing at its item, so that every
/// device finds the same items by the store's own links — an item has no id the devices share.
///
/// Causabee's own links — a task's mail, a file's mail — are not kept here: they come from the
/// item's `sources` as before. When the owner takes one of those away, a connection of the kind
/// `notFrom` says so, and the link is not shown again.
@Model
public final class Connection {
    public enum Kind: String, Codable, Sendable { case with, notFrom }
    public var kindRaw: String = Kind.with.rawValue
    public var createdAt: Date = Date()
    public var matter: Matter?
    @Relationship(deleteRule: .cascade, inverse: \ConnectionEnd.connection) public var ends: [ConnectionEnd]? = []

    public init(kind: Kind) { kindRaw = kind.rawValue }

    public var kind: Kind { Kind(rawValue: kindRaw) ?? .with }

    /// Its two items; fewer when one of them was deleted.
    public var items: [JournalItem] { (ends ?? []).compactMap(JournalItem.init) }
}

/// One end of a connection: one of these points at its item, the others are nil.
@Model
public final class ConnectionEnd {
    public var connection: Connection?
    public var entry: Entry?
    public var document: Document?
    public var todo: Todo?
    public var appointment: Appointment?
    public var deadline: Deadline?
    public var note: MatterNote?
    public var link: WebLink?
    public var person: Party?
    public var detail: MatterDetail?

    public init() {}
}

/// Anything of a matter that can be connected: what came in, what is to do, what is known, who.
public enum JournalItem: Hashable {
    case mail(Entry), file(Document), task(Todo), meeting(Appointment), deadline(Deadline)
    case note(MatterNote), link(WebLink), person(Party), detail(MatterDetail)

    init?(_ end: ConnectionEnd) {
        if let item = end.entry { self = .mail(item) }
        else if let item = end.document { self = .file(item) }
        else if let item = end.todo { self = .task(item) }
        else if let item = end.appointment { self = .meeting(item) }
        else if let item = end.deadline { self = .deadline(item) }
        else if let item = end.note { self = .note(item) }
        else if let item = end.link { self = .link(item) }
        else if let item = end.person { self = .person(item) }
        else if let item = end.detail { self = .detail(item) }
        else { return nil }
    }

    func point(_ end: ConnectionEnd) {
        switch self {
        case .mail(let item): end.entry = item
        case .file(let item): end.document = item
        case .task(let item): end.todo = item
        case .meeting(let item): end.appointment = item
        case .deadline(let item): end.deadline = item
        case .note(let item): end.note = item
        case .link(let item): end.link = item
        case .person(let item): end.person = item
        case .detail(let item): end.detail = item
        }
    }

    public var id: PersistentIdentifier {
        switch self {
        case .mail(let item): item.persistentModelID
        case .file(let item): item.persistentModelID
        case .task(let item): item.persistentModelID
        case .meeting(let item): item.persistentModelID
        case .deadline(let item): item.persistentModelID
        case .note(let item): item.persistentModelID
        case .link(let item): item.persistentModelID
        case .person(let item): item.persistentModelID
        case .detail(let item): item.persistentModelID
        }
    }

    public static func == (a: JournalItem, b: JournalItem) -> Bool { a.id == b.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The words it is shown by in a chip.
    public var title: String {
        switch self {
        case .mail(let item): item.title
        case .file(let item): item.shownName
        case .task(let item): item.text
        case .meeting(let item): item.what
        case .deadline(let item): item.what
        case .note(let item): String(item.text.prefix(60))
        case .link(let item): item.title.isEmpty ? item.address : item.title
        case .person(let item): item.name
        case .detail(let item): item.label
        }
    }

    /// The Message-ID it carries, for Causabee's own links: a mail's own, a file's mail's.
    var messageID: String? {
        switch self {
        case .mail(let item): item.messageID
        case .file(let item): item.messageID
        default: nil
        }
    }

    /// The Message-IDs it came from, as Causabee read it.
    var sourceIDs: Set<String> {
        let sources: [Source] = switch self {
        case .task(let item): item.sources + (item.doneSource.map { [$0] } ?? [])
        case .meeting(let item): item.sources
        case .deadline(let item): item.sources
        default: []
        }
        return Set(sources.compactMap(\.messageID))
    }

    var ends: [ConnectionEnd] {
        switch self {
        case .mail(let item): item.connectionEnds ?? []
        case .file(let item): item.connectionEnds ?? []
        case .task(let item): item.connectionEnds ?? []
        case .meeting(let item): item.connectionEnds ?? []
        case .deadline(let item): item.connectionEnds ?? []
        case .note(let item): item.connectionEnds ?? []
        case .link(let item): item.connectionEnds ?? []
        case .person(let item): item.connectionEnds ?? []
        case .detail(let item): item.connectionEnds ?? []
        }
    }
}

/// Another item, as one item shows it.
public struct Connected: Hashable {
    public enum Kind: Hashable { case cameFrom, with }
    public var item: JournalItem
    public var kind: Kind
}

extension Matter {
    /// Every item of the matter that can be connected, the people included.
    public var journalItems: [JournalItem] {
        (entries ?? []).map(JournalItem.mail) + (documents ?? []).map(JournalItem.file) + (todos ?? []).map(JournalItem.task)
            + (appointments ?? []).map(JournalItem.meeting) + (deadlines ?? []).map(JournalItem.deadline)
            + (noteBlocks ?? []).map(JournalItem.note) + (links ?? []).map(JournalItem.link)
            + parties.map(JournalItem.person) + (details ?? []).map(JournalItem.detail)
    }

    /// The connections of this matter between these two items, of this kind.
    private func connections(_ a: JournalItem, _ b: JournalItem, kind: Connection.Kind) -> [Connection] {
        (connections ?? []).filter { !$0.isDeleted && $0.kind == kind && Set($0.items) == [a, b] }
    }

    /// What one item is connected to: Causabee's own links first, then the owner's, each once.
    public func connected(to item: JournalItem) -> [Connected] {
        let all = journalItems
        var cameFrom: [JournalItem] = []
        // What it came from: the mail or file its sources name.
        let ids = item.sourceIDs
        if !ids.isEmpty {
            cameFrom += all.filter { other in
                guard let id = other.messageID, ids.contains(id) else { return false }
                // A mail by its entry; a file dropped in by its file, which is what the owner sees.
                if case .mail(let entry) = other { return entry.source.kind == .mail }
                if case .file(let document) = other { return document.source.kind != .mail }
                return false
            }
        }
        // A file and the mail it came in, both ways; and what a mail or file brought.
        if let id = item.messageID {
            for other in all where other != item {
                switch (item, other) {
                case (.file(let document), .mail(let entry)) where document.source.kind == .mail && entry.messageID == id: cameFrom.append(other)
                case (.mail(let entry), .file(let document)) where entry.messageID == id && document.source.kind == .mail: cameFrom.append(other)
                case (.mail, .task), (.mail, .meeting), (.mail, .deadline), (.file, .task), (.file, .meeting), (.file, .deadline):
                    if other.sourceIDs.contains(id) {
                        if case .file(let document) = item, document.source.kind == .mail { break }
                        cameFrom.append(other)
                    }
                default: break
                }
            }
        }
        let taken = Set((connections ?? []).filter { !$0.isDeleted && $0.kind == .notFrom && $0.items.contains(item) }.flatMap(\.items))
        var out: [Connected] = []
        var seen: Set<JournalItem> = [item]
        for other in cameFrom where !taken.contains(other) && seen.insert(other).inserted { out.append(Connected(item: other, kind: .cameFrom)) }
        let mine = item.ends.compactMap(\.connection).filter { !$0.isDeleted && $0.kind == .with && $0.matter === self }.sorted { $0.createdAt < $1.createdAt }
        for connection in mine {
            for other in connection.items where seen.insert(other).inserted { out.append(Connected(item: other, kind: .with)) }
        }
        return out
    }

    /// Puts two items of the matter together. Nothing when they are already, or are the same.
    @discardableResult
    public func connect(_ a: JournalItem, _ b: JournalItem, in context: ModelContext) -> Connection? {
        guard a != b, !connected(to: a).contains(where: { $0.item == b }) else { return nil }
        // Taken apart once and put together again: the mark that kept them apart goes.
        for mark in connections(a, b, kind: .notFrom) { context.delete(mark) }
        guard !connected(to: a).contains(where: { $0.item == b }) else { return nil }
        let connection = Connection(kind: .with)
        context.insert(connection)
        connection.matter = self
        for item in [a, b] {
            let end = ConnectionEnd()
            context.insert(end)
            item.point(end)
            end.connection = connection
        }
        return connection
    }

    /// Takes two items apart, from both ends; both stay. One of Causabee's own links is marked so
    /// that it is not shown again.
    public func disconnect(_ a: JournalItem, _ b: JournalItem, in context: ModelContext) {
        let link = connected(to: a).first { $0.item == b }
        for connection in connections(a, b, kind: .with) { context.delete(connection) }
        if link?.kind == .cameFrom {
            let mark = Connection(kind: .notFrom)
            context.insert(mark)
            mark.matter = self
            for item in [a, b] {
                let end = ConnectionEnd()
                context.insert(end)
                item.point(end)
                end.connection = mark
            }
        }
    }
}
