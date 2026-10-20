import Foundation
import SwiftData

/// What came from each thing of the record, and where in the record each fact came from: the
/// links both ways between a matter's tasks and dates and the mails, scans and files they were
/// read out of. Built from the sources the facts already keep — no relationship of its own in
/// the store, so nothing changes for iCloud, and every device finds the same links.
public struct RecordLinks {
    /// The tasks, appointments and deadlines that name one thing of the record as their source.
    public struct Made {
        public var todos: [Todo] = []
        public var appointments: [Appointment] = []
        public var deadlines: [Deadline] = []

        public init() {}
        public var isEmpty: Bool { todos.isEmpty && appointments.isEmpty && deadlines.isEmpty }
        public var count: Int { todos.count + appointments.count + deadlines.count }
    }

    private var made: [String: Made] = [:]

    /// Once per drawing of a record: every fact of the matter, filed under each source it names.
    /// A task that a mail showed done counts for that mail too.
    public init(_ matter: Matter) {
        for todo in matter.todos ?? [] {
            var keys = Set(todo.sources.flatMap(Self.keys))
            if let done = todo.doneSource { keys.formUnion(Self.keys(done)) }
            for key in keys { made[key, default: Made()].todos.append(todo) }
        }
        for appointment in matter.appointments ?? [] {
            for key in Set(appointment.sources.flatMap(Self.keys)) { made[key, default: Made()].appointments.append(appointment) }
        }
        for deadline in matter.deadlines ?? [] {
            for key in Set(deadline.sources.flatMap(Self.keys)) { made[key, default: Made()].deadlines.append(deadline) }
        }
        for key in made.keys {
            made[key]?.todos.sort { ($0.isDone ? 1 : 0, $0.due ?? "9999", $0.createdAt) < ($1.isDone ? 1 : 0, $1.due ?? "9999", $1.createdAt) }
            made[key]?.appointments.sort { $0.day < $1.day }
            made[key]?.deadlines.sort { $0.day < $1.day }
        }
    }

    /// What came from a mail of the record.
    public func made(from entry: Entry) -> Made { made(messageID: entry.messageID, pointer: entry.source.pointer) }

    /// What came from a file of the record. A file that came with a mail counts with its mail, so
    /// it shows nothing of its own.
    public func made(from document: Document) -> Made { made(messageID: document.messageID, pointer: document.source.pointer) }

    private func made(messageID: String, pointer: String) -> Made {
        var all = Made()
        var seen = Set<PersistentIdentifier>()
        for key in [messageID.isEmpty ? nil : "id:" + messageID, pointer.isEmpty ? nil : "at:" + pointer].compactMap({ $0 }) {
            guard let found = made[key] else { continue }
            for todo in found.todos where seen.insert(todo.persistentModelID).inserted { all.todos.append(todo) }
            for appointment in found.appointments where seen.insert(appointment.persistentModelID).inserted { all.appointments.append(appointment) }
            for deadline in found.deadlines where seen.insert(deadline.persistentModelID).inserted { all.deadlines.append(deadline) }
        }
        return all
    }

    /// The keys a source is found by: its Message-ID, and where it points.
    static func keys(_ source: Source) -> [String] {
        var keys: [String] = []
        if let id = source.messageID, !id.isEmpty { keys.append("id:" + id) }
        if !source.pointer.isEmpty, source.kind != .conversation { keys.append("at:" + source.pointer) }
        return keys
    }

    /// The thing of the record a source points at — its mail first, else its file — or nil when it
    /// is not in this matter's record (the owner in the assistant, a mail moved away).
    public static func item(for source: Source?, in matter: Matter) -> PersistentIdentifier? {
        guard let source, source.kind != .conversation else { return nil }
        let entries = matter.entries ?? [], documents = matter.documents ?? []
        if let id = source.messageID, !id.isEmpty {
            if let entry = matter.entry(messageID: id) { return entry.persistentModelID }
            if let document = documents.first(where: { $0.messageID == id }) { return document.persistentModelID }
        }
        guard !source.pointer.isEmpty else { return nil }
        if let entry = entries.first(where: { $0.source.pointer == source.pointer }) { return entry.persistentModelID }
        return documents.first { $0.source.pointer == source.pointer }?.persistentModelID
    }
}
