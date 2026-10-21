import Foundation
import SwiftData

/// A matter's mails by their Message-ID, kept until its mails change: whether a file was read,
/// who sent it, where a task's source is — each looked up, where each was a search through all the
/// matter's mails, and asked many times every time a page is drawn.
enum MailIndex {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var kept: [PersistentIdentifier: (count: Int, byID: [String: Entry])] = [:]

    static func entry(_ messageID: String, in matter: Matter) -> Entry? {
        guard !messageID.isEmpty else { return nil }
        let entries = matter.entries ?? []
        let id = matter.persistentModelID
        lock.lock()
        let index = kept[id]
        lock.unlock()
        if let index, index.count == entries.count, let found = index.byID[messageID] {
            // Still that mail, and still in this matter: a mail moved out and another in keeps the count.
            if !found.isDeleted, found.modelContext != nil, found.messageID == messageID, found.matter === matter { return found }
        } else if let index, index.count == entries.count, index.byID[messageID] == nil {
            return nil
        }
        var byID: [String: Entry] = [:]
        for entry in entries where !entry.messageID.isEmpty && byID[entry.messageID] == nil { byID[entry.messageID] = entry }
        lock.lock()
        kept[id] = (entries.count, byID)
        lock.unlock()
        return byID[messageID]
    }
}

extension Matter {
    /// Its mail with this Message-ID.
    public func entry(messageID: String) -> Entry? { MailIndex.entry(messageID, in: self) }
}

/// How many of a matter's records are of each kind — mails, screenshots, documents — counted away
/// from the screen: each one's source has to be read for it, and with a few hundred that held the
/// matter's page for a tenth of a second each time it came up.
public enum RecordKinds {
    public static func count(of matter: PersistentIdentifier, in container: ModelContainer) -> [Source.Kind: Int] {
        let context = ModelContext(container)
        let entries = (try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.matter?.persistentModelID == matter }))) ?? []
        var counts: [Source.Kind: Int] = [:]
        for entry in entries { counts[entry.source.kind, default: 0] += 1 }
        return counts
    }
}
