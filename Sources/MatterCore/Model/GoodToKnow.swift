import Foundation
import SwiftData

/// What is good to know about a matter: true, asking nothing of the owner, wanted at hand when
/// they act — a rule that applies, an arrangement, a limit, some background. Pro writes it with the
/// brief, from the mail it rests on; nobody adds it by hand. It is kept as a to-do that is only
/// worth knowing (`isInfo`), its origin marked as Pro's, so the iCloud schema stays as it is.
extension Todo {
    /// The origin of a fact Pro wrote: the prefix, and its words folded.
    public static let factPrefix = "fact#"
    /// The source that carries the day a fact holds until, in its quote, as `YYYY-MM-DD`.
    static let untilPointer = "until"

    /// Written by Pro with the brief, not by the owner.
    public var isFact: Bool { origin.hasPrefix(Self.factPrefix) }

    /// The day it holds until, `YYYY-MM-DD` — an offer, a period — when it holds only until then.
    public var holdsUntil: String? {
        get { sources.first { $0.kind == .conversation && $0.pointer == Self.untilPointer }?.quote }
        set {
            sources.removeAll { $0.kind == .conversation && $0.pointer == Self.untilPointer }
            if let newValue, !newValue.isEmpty { sources.append(Source(kind: .conversation, pointer: Self.untilPointer, quote: newValue)) }
        }
    }

    /// Where it came from, without the day it holds until.
    public var factSources: [Source] { sources.filter { !($0.kind == .conversation && $0.pointer == Self.untilPointer) } }

    /// Its day has passed: it may no longer be true.
    public func mayBeOutdated(today: String) -> Bool { holdsUntil.map { $0 < today } ?? false }
}

/// One fact as the adviser gave it, in real names: its words, the mails or files it rests on,
/// the fact it is again when it was given before, and the day it holds until.
public struct GoodToKnowFact: Sendable, Equatable {
    public var text: String
    public var sources: [Source]
    /// The fact already in the matter it is again.
    public var same: PersistentIdentifier?
    public var until: String?

    public init(text: String, sources: [Source], same: PersistentIdentifier? = nil, until: String? = nil) {
        self.text = text
        self.sources = sources
        self.same = same
        self.until = until
    }
}

extension Matter {
    /// Pro's facts as they are now: one given again keeps its place, in better words when it has
    /// them; a new one comes in; one of Pro's no longer given is no longer true, and goes. What the
    /// owner hid stays hidden — given again, it is not brought back. What the owner kept by hand
    /// is the owner's, and stays.
    public func putFacts(_ facts: [GoodToKnowFact], in context: ModelContext, at now: Date = Date()) {
        let ours = (todos ?? []).filter { $0.isInfo && $0.isFact }
        var kept = Set<PersistentIdentifier>()
        for fact in facts.prefix(8) {
            let text = fact.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let origin = Todo.factPrefix + MatterImport.key(text)
            let found = fact.same.flatMap { id in ours.first { $0.persistentModelID == id } } ?? ours.first { $0.origin == origin }
            if let found {
                kept.insert(found.persistentModelID)
                guard !found.isHidden else { continue }
                found.text = text
                for source in fact.sources where !found.sources.contains(where: { $0.pointer == source.pointer && $0.messageID == source.messageID }) {
                    found.sources.insert(source, at: found.factSources.count)
                }
                found.holdsUntil = fact.until
                continue
            }
            // Something the owner keeps by hand already says it: not twice.
            if (todos ?? []).contains(where: { $0.isInfo && !$0.isFact && MatterImport.key($0.text) == MatterImport.key(text) }) { continue }
            let todo = Todo(text: text, owner: .unknown, due: nil,
                            source: fact.sources.first ?? Source(kind: .conversation, pointer: "brief"), origin: origin)
            todo.sources = fact.sources.isEmpty ? todo.sources : fact.sources
            todo.isInfo = true
            todo.createdAt = now
            todo.holdsUntil = fact.until
            context.insert(todo)
            todo.matter = self
            kept.insert(todo.persistentModelID)
        }
        // No longer given: no longer true. Hidden, it stays, so it is not brought back.
        let gone = ours.filter { !kept.contains($0.persistentModelID) && !$0.isHidden }
        // Out of the matter at once, not only at the next save: the page reads it right after.
        todos?.removeAll { todo in gone.contains { $0 === todo } }
        for todo in gone { context.delete(todo) }
    }

    /// The facts the owner hid, said to the adviser so it does not give them again.
    public var hiddenFacts: [String] {
        (todos ?? []).filter { $0.isInfo && $0.isFact && $0.isHidden }.map(\.text)
    }
}
