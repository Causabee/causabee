import Foundation
import SwiftData

/// What came into a matter twice. Two devices each sorted the same mail before iCloud had brought
/// either the other's work: its entry, its tasks, its files and its dates stood twice. And a file
/// the owner added by hand that a mail brought too — often from the matter's own folder, where
/// it stands with its day in front of its name.
///
/// Every device puts it right in the same way, so that two of them doing it at once never take
/// away both: the one kept is chosen by what tells them apart. Where nothing does, only the device
/// that sorted the mail first takes the second away.
public enum Twins {
    /// A file's name without the days put in front of it in a matter's folder: "2026-10-30 Rechnung.pdf".
    static func bareName(_ name: String) -> String {
        var name = name
        while let day = name.firstMatch(of: #/^\d{4}-\d{2}-\d{2} /#) { name.removeSubrange(day.range) }
        return name.precomposedStringWithCanonicalMapping
    }

    /// The same file: as many bytes, and the same name once the days in front of it are gone.
    static func same(_ a: (name: String, bytes: Int), _ b: (name: String, bytes: Int)) -> Bool {
        a.bytes > 0 && a.bytes == b.bytes && bareName(a.name) == bareName(b.name)
    }

    static func byHand(_ document: Document) -> Bool { [.document, .screenshot].contains(document.source.kind) }

    /// The matter has this file already, from a mail or added before.
    public static func has(_ name: String, bytes: Int, in matter: Matter) -> Bool {
        (matter.documents ?? []).contains { same(($0.name, $0.byteCount), (name, bytes)) }
    }

    /// A mail brought a file the owner had added by hand: the hand-added one is put away — hidden,
    /// not deleted, so it can be put back. The mail's stays, beside its mail.
    @discardableResult
    static func putAway(handAddedTwinsOf document: Document, in matter: Matter) -> Int {
        var put = 0
        for other in matter.documents ?? [] where other !== document && byHand(other) && !other.isHidden
            && same((other.name, other.byteCount), (document.name, document.byteCount)) {
            other.isHidden = true
            put += 1
        }
        return put
    }

    public struct Tidied: Equatable, Sendable {
        public var mails = 0, todos = 0, files = 0, dates = 0
        public var any: Bool { mails + todos + files + dates > 0 }
    }

    /// Everything that came in twice, put right. `device`: this device's id, as `SortedMail` has it.
    @discardableResult
    public static func tidy(in context: ModelContext, device: String) throws -> Tidied {
        var tidied = Tidied()
        // The device that sorted each mail first, and so takes away a twin nothing tells apart.
        var first: [String: (at: Date, device: String)] = [:]
        for record in try context.fetch(FetchDescriptor<SortedMail>()) where !record.data.isEmpty {
            let mine = (record.sortedAt, record.device)
            if let known = first[record.messageID], (known.at, known.device) <= mine { continue }
            first[record.messageID] = mine
        }
        func leads(_ id: String) -> Bool { !device.isEmpty && first[id]?.device == device }

        for matter in try context.fetch(FetchDescriptor<Matter>()) {
            // Tasks: the same origin is the same task from the same mail. The older one stays.
            for (_, twins) in Dictionary(grouping: (matter.todos ?? []).filter { !$0.origin.isEmpty }, by: \.origin) where twins.count > 1 {
                let sorted = twins.sorted { $0.createdAt < $1.createdAt }
                guard sorted[0].createdAt < sorted[1].createdAt || leads(String(sorted[0].origin.prefix { $0 != "#" })) else { continue }
                let kept = sorted[0]
                for twin in sorted.dropFirst() {
                    if twin.isDone, !kept.isDone { kept.isDone = true; kept.doneAt = twin.doneAt; kept.doneSource = twin.doneSource }
                    if kept.reminderID == nil { kept.reminderID = twin.reminderID; kept.reminderStamp = twin.reminderStamp }
                    if kept.note == nil { kept.note = twin.note }
                    if kept.waitsFor == nil, let waits = twin.waitsFor, waits !== kept { kept.wait(for: waits) }
                    for other in twin.unblocks ?? [] where other !== kept { other.wait(for: kept) }
                    context.delete(twin)
                    tidied.todos += 1
                }
            }
            // Mails: the one whose summary comes first stays; two the same in every word, only the first sorter.
            for (id, twins) in Dictionary(grouping: (matter.entries ?? []).filter { !$0.messageID.isEmpty }, by: \.messageID) where twins.count > 1 {
                let key: (Entry) -> String = { ($0.digest ?? "\u{10FFFF}") + "\u{0}" + $0.title + "\u{0}" + $0.from }
                let sorted = twins.sorted { key($0) < key($1) }
                guard key(sorted[0]) < key(sorted[1]) || leads(id) else { continue }
                for twin in sorted.dropFirst() { context.delete(twin); tidied.mails += 1 }
            }
            // Files of one mail with one name: one that was read, named or hidden by the owner stays.
            for (_, twins) in Dictionary(grouping: matter.documents ?? [], by: { $0.messageID + "/" + $0.name }) where twins.count > 1 {
                let key: (Document) -> String = { ($0.isHidden ? "1" : "0") + ($0.readAt == nil ? "1" : "0") + ($0.title ?? "\u{10FFFF}") }
                let sorted = twins.sorted { key($0) < key($1) }
                guard key(sorted[0]) < key(sorted[1]) || leads(sorted[0].messageID) else { continue }
                for twin in sorted.dropFirst() { context.delete(twin); tidied.files += 1 }
            }
            // Dates from the same mail, on the same day, about the same: one in the calendar stays.
            func dates<Item: PersistentModel>(_ items: [Item], key: (Item) -> String, linked: (Item) -> Bool, source: (Item) -> String) {
                for (_, twins) in Dictionary(grouping: items, by: key) where twins.count > 1 {
                    let sorted = twins.sorted { linked($0) && !linked($1) }
                    guard linked(sorted[0]) != linked(sorted[1]) || leads(source(sorted[0])) else { continue }
                    for twin in sorted.dropFirst() { context.delete(twin); tidied.dates += 1 }
                }
            }
            dates((matter.appointments ?? []).filter { $0.sources.count == 1 },
                  key: { "\($0.sources[0].messageID ?? "")|\($0.day)|\($0.time ?? "")|\($0.what)" },
                  linked: { $0.calendarID != nil }, source: { $0.sources[0].messageID ?? "" })
            dates((matter.deadlines ?? []).filter { $0.sources.count == 1 },
                  key: { "\($0.sources[0].messageID ?? "")|\($0.day)|\($0.what)" },
                  linked: { $0.calendarID != nil }, source: { $0.sources[0].messageID ?? "" })
        }
        if tidied.any { try context.save() }
        return tidied
    }

    /// Once on each device: files added by hand before this was put right, that a mail brought
    /// too, put away. Only once, so a file the owner shows again stays shown.
    @discardableResult
    public static func putAwayHandAddedTwins(in context: ModelContext) throws -> Int {
        var put = 0
        for matter in try context.fetch(FetchDescriptor<Matter>()) {
            for document in matter.documents ?? [] where document.source.kind == .mail {
                put += putAway(handAddedTwinsOf: document, in: matter)
            }
        }
        if put > 0 { try context.save() }
        return put
    }
}
