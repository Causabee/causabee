import Foundation
import SwiftData

/// What the owner deletes by hand — a task, a date, a note, a detail, a link — goes, and can be
/// brought back: Edit → Undo on the Mac and the iPad, a shake on the iPhone. Only that is undone:
/// what a mail check or the assistant writes never reaches the undo manager.
///
/// The store does not take a delete back by itself, so what goes is written down first and made
/// anew from that: its words, its matter, what hung on it. Not its reminder or its entry in
/// Calendar — those were removed with it, and it comes back unconnected. Redo deletes it again.
public extension ModelContext {
    @MainActor
    func deleteByHand(_ models: [any PersistentModel], undo: UndoManager?, named name: String) {
        let kept = models.compactMap(Kept.init)
        for model in models { delete(model) }
        try? save()
        guard let undo, !kept.isEmpty else { return }
        undo.registerUndo(withTarget: self) { context in
            MainActor.assumeIsolated {
                let back = kept.map { $0.putBack(in: context) }
                try? context.save()
                // Registered while undoing, this is the Redo: what came back goes again.
                undo.registerUndo(withTarget: context) { context in
                    MainActor.assumeIsolated { context.deleteByHand(back, undo: undo, named: name) }
                }
                undo.setActionName(name)
            }
        }
        undo.setActionName(name)
    }
}

/// One deleted thing, as it stood.
private enum Kept: @unchecked Sendable {
    case todo(text: String, ownerRaw: String, due: String?, dueTime: String?, note: String?, isDone: Bool, isInfo: Bool,
              doneAt: Date?, doneSource: Source?, sources: [Source], origin: String, createdAt: Date,
              matter: PersistentIdentifier?, waitsFor: PersistentIdentifier?, unblocks: [PersistentIdentifier], links: [PersistentIdentifier])
    case appointment(what: String, day: String, time: String?, place: String?, sources: [Source], matter: PersistentIdentifier?)
    case deadline(what: String, day: String, sources: [Source], matter: PersistentIdentifier?)
    case detail(label: String, value: String, createdAt: Date, matter: PersistentIdentifier?, party: PersistentIdentifier?)
    case note(text: String, createdAt: Date, fromAssistant: Bool, matter: PersistentIdentifier?)
    case link(address: String, title: String, createdAt: Date, messageID: String, isSuggestion: Bool, isDismissed: Bool,
              matter: PersistentIdentifier?, todo: PersistentIdentifier?)

    init?(_ model: any PersistentModel) {
        switch model {
        case let todo as Todo:
            self = .todo(text: todo.text, ownerRaw: todo.ownerRaw, due: todo.due, dueTime: todo.dueTime, note: todo.note,
                         isDone: todo.isDone, isInfo: todo.isInfo, doneAt: todo.doneAt, doneSource: todo.doneSource,
                         sources: todo.sources, origin: todo.origin, createdAt: todo.createdAt,
                         matter: todo.matter?.persistentModelID, waitsFor: todo.waitsFor?.persistentModelID,
                         unblocks: (todo.unblocks ?? []).map(\.persistentModelID), links: (todo.links ?? []).map(\.persistentModelID))
        case let item as Appointment:
            self = .appointment(what: item.what, day: item.day, time: item.time, place: item.place, sources: item.sources,
                                matter: item.matter?.persistentModelID)
        case let item as Deadline:
            self = .deadline(what: item.what, day: item.day, sources: item.sources, matter: item.matter?.persistentModelID)
        case let detail as MatterDetail:
            self = .detail(label: detail.label, value: detail.value, createdAt: detail.createdAt,
                           matter: detail.matter?.persistentModelID, party: detail.party?.persistentModelID)
        case let note as MatterNote:
            self = .note(text: note.text, createdAt: note.createdAt, fromAssistant: note.fromAssistant, matter: note.matter?.persistentModelID)
        case let link as WebLink:
            self = .link(address: link.address, title: link.title, createdAt: link.createdAt, messageID: link.messageID,
                         isSuggestion: link.isSuggestion, isDismissed: link.isDismissed,
                         matter: link.matter?.persistentModelID, todo: link.todo?.persistentModelID)
        default:
            return nil
        }
    }

    /// Something by its id, if it is still there: a matter closed for good or a task deleted
    /// since is not put back on.
    private static func live<T: PersistentModel>(_ id: PersistentIdentifier?, as type: T.Type, in context: ModelContext) -> T? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// A stand-in where the first mail is asked for and there was none.
    private static let byHand = Source(kind: .conversation, pointer: "")

    @MainActor @discardableResult
    func putBack(in context: ModelContext) -> any PersistentModel {
        switch self {
        case let .todo(text, ownerRaw, due, dueTime, note, isDone, isInfo, doneAt, doneSource, sources, origin, createdAt, matter, waitsFor, unblocks, links):
            let todo = Todo(text: text, owner: .unknown, due: due, source: sources.first ?? Self.byHand, origin: origin)
            todo.ownerRaw = ownerRaw
            todo.dueTime = dueTime
            todo.note = note
            todo.isDone = isDone
            todo.isInfo = isInfo
            todo.doneAt = doneAt
            todo.doneSource = doneSource
            todo.sources = sources
            todo.createdAt = createdAt
            context.insert(todo)
            todo.matter = Self.live(matter, as: Matter.self, in: context)
            todo.waitsFor = Self.live(waitsFor, as: Todo.self, in: context)
            // What waited for it waits for it again, unless it waits for something else by now.
            for id in unblocks {
                if let other = Self.live(id, as: Todo.self, in: context), other.waitsFor == nil { other.waitsFor = todo }
            }
            for id in links {
                if let link = Self.live(id, as: WebLink.self, in: context), link.todo == nil { link.todo = todo }
            }
            return todo
        case let .appointment(what, day, time, place, sources, matter):
            let item = Appointment(what: what, day: day, time: time, place: place, source: sources.first ?? Self.byHand)
            item.sources = sources
            context.insert(item)
            item.matter = Self.live(matter, as: Matter.self, in: context)
            return item
        case let .deadline(what, day, sources, matter):
            let item = Deadline(what: what, day: day, source: sources.first ?? Self.byHand)
            item.sources = sources
            context.insert(item)
            item.matter = Self.live(matter, as: Matter.self, in: context)
            return item
        case let .detail(label, value, createdAt, matter, party):
            let detail = MatterDetail(label: label, value: value, createdAt: createdAt)
            context.insert(detail)
            detail.matter = Self.live(matter, as: Matter.self, in: context)
            detail.party = Self.live(party, as: Party.self, in: context)
            return detail
        case let .note(text, createdAt, fromAssistant, matter):
            let note = MatterNote(text: text, createdAt: createdAt, fromAssistant: fromAssistant)
            context.insert(note)
            note.matter = Self.live(matter, as: Matter.self, in: context)
            return note
        case let .link(address, title, createdAt, messageID, isSuggestion, isDismissed, matter, todo):
            let link = WebLink(address: address, title: title)
            link.createdAt = createdAt
            link.messageID = messageID
            link.isSuggestion = isSuggestion
            link.isDismissed = isDismissed
            context.insert(link)
            link.matter = Self.live(matter, as: Matter.self, in: context)
            link.todo = Self.live(todo, as: Todo.self, in: context)
            return link
        }
    }
}
