import Foundation
import SwiftData

/// The record, browsed: which kind of thing, which of them, in which order — and the groups they
/// stand in. The same on every device; the screens only draw what this hands them.
public enum RecordBrowse {
    public enum Kind: String, CaseIterable, Sendable {
        case everything, mail, files, scans, links, details

        public var label: String {
            switch self {
            case .everything: "Everything"
            case .mail: "Mail"
            case .files: "Files"
            case .scans: "Scans"
            case .links: "Links"
            case .details: "Details"
            }
        }
    }

    public enum Show: String, CaseIterable, Sendable {
        case all, withFacts, info, kept, unread

        public var label: String {
            switch self {
            case .all: "All"
            case .withFacts: "With tasks or dates"
            case .info: "Information only"
            case .kept: "Kept only"
            case .unread: "Unread"
            }
        }
    }

    public enum Sort: String, CaseIterable, Sendable {
        case newest, oldest, byPerson, byKind

        public var label: String {
            switch self {
            case .newest: "Newest"
            case .oldest: "Oldest"
            case .byPerson: "By person"
            case .byKind: "By kind"
            }
        }
    }

    /// One thing of the record: a conversation, a file of its own, or a link.
    public enum Item: Identifiable {
        case thread(MailThreads.Thread)
        case document(Document)
        case link(WebLink)

        public var id: String {
            switch self {
            case .thread(let thread): "thread-\(thread.id)"
            case .document(let document): "file-\(document.persistentModelID.hashValue)"
            case .link(let link): "link-\(link.persistentModelID.hashValue)"
            }
        }

        public var date: Date {
            switch self {
            case .thread(let thread): thread.last ?? thread.first ?? .distantPast
            case .document(let document): document.source.date ?? .distantPast
            case .link(let link): link.createdAt
            }
        }

        var kindName: String {
            switch self {
            case .thread: "Mail"
            case .document(let document): document.isOwnFile ? "Scans and files of your own" : "Files from mail"
            case .link: "Links"
            }
        }
    }

    /// A heading and what stands under it. By person, a thing can stand under several: `also`
    /// names the others.
    public struct Group: Identifiable {
        public var title: String
        public var items: [Item]
        public var also: [String: [String]] = [:]
        public var id: String { title }
    }

    /// What the record holds, cut by kind and show — conversations, files on their own, links —
    /// and the files of a mail, which stand under it rather than on their own.
    public struct Picked {
        public var items: [Item]
        /// The files that came with a mail, by the conversation they stand under.
        public var attached: [String: [Document]]
    }

    public static func pick(threads: [MailThreads.Thread], documents: [Document], links: [WebLink],
                            kind: Kind, show: Show, made: RecordLinks) -> Picked {
        let mailIDs = Dictionary(threads.flatMap { thread in thread.rows.map { ($0.entry.messageID, thread.id) } }.filter { !$0.0.isEmpty },
                                 uniquingKeysWith: { first, _ in first })
        // Files kind: every file on its own. Otherwise a file that came with a mail stands under it.
        let alone = kind == .files || kind == .scans
        var attached = alone ? [:] : Dictionary(grouping: documents.filter { mailIDs[$0.messageID] != nil && !$0.isOwnFile }) { mailIDs[$0.messageID] ?? "" }
        // A scan or a picture the owner brought in is its entry already — "Open" is on it — and
        // is not listed again beside it.
        let loose = alone ? documents : documents.filter { mailIDs[$0.messageID] == nil }

        func hasFacts(_ thread: MailThreads.Thread) -> Bool {
            thread.rows.contains { !made.made(from: $0.entry).isEmpty }
        }
        func keeps(_ document: Document) -> Bool {
            switch show {
            case .all: true
            case .withFacts: !made.made(from: document).isEmpty
            case .info: made.made(from: document).isEmpty
            case .kept: document.reading != .read
            case .unread: false
            }
        }
        var items: [Item] = []
        if kind == .everything || kind == .mail {
            for thread in threads {
                switch show {
                case .all: items.append(.thread(thread))
                case .withFacts: if hasFacts(thread) { items.append(.thread(thread)) }
                case .info: if !hasFacts(thread) { items.append(.thread(thread)) }
                case .unread: if thread.rows.contains(where: { $0.entry.isUnread == true }) { items.append(.thread(thread)) }
                case .kept:
                    // The mails whose files are kept only, with only those files under them.
                    let files = (attached[thread.id] ?? []).filter { $0.reading != .read }
                    if !files.isEmpty { items.append(.thread(thread)); attached[thread.id] = files }
                }
            }
        }
        if kind == .everything || kind == .files || kind == .scans, show != .unread {
            for document in loose where (kind != .scans || document.isOwnFile) && keeps(document) { items.append(.document(document)) }
        }
        if (kind == .everything || kind == .links) && (show == .all || show == .info) {
            items += links.map(Item.link)
        }
        return Picked(items: items, attached: attached)
    }

    /// One line of the record as a list draws it, heading after heading with what stands under
    /// each: one flat list, so that only what is near the screen need be drawn. A thing under
    /// several people has a line under each.
    public enum Line: Identifiable {
        case title(Group, first: Bool)
        case item(Item, under: String, also: [String])

        public var id: String {
            switch self {
            case .title(let group, _): "title \(group.id)"
            case .item(let item, let under, _): "\(under) \(item.id)"
            }
        }
    }

    public static func lines(of groups: [Group]) -> [Line] {
        groups.enumerated().flatMap { index, group in
            [Line.title(group, first: index == 0)] + group.items.map { Line.item($0, under: group.title, also: group.also[$0.id] ?? []) }
        }
    }

    /// The line a mail, a file or a link stands on: what is not near the screen is not drawn, so
    /// going to it goes to its line first.
    public static func line(of model: PersistentIdentifier, in lines: [Line], attached: [String: [Document]]) -> String? {
        lines.first { line in
            guard case .item(let item, _, _) = line else { return false }
            switch item {
            case .thread(let thread):
                return thread.rows.contains { $0.entry.persistentModelID == model }
                    || (attached[thread.id] ?? []).contains { $0.persistentModelID == model }
            case .document(let document): return document.persistentModelID == model
            case .link(let link): return link.persistentModelID == model
            }
        }?.id
    }

    private static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    /// The groups, in order. `people` names who is named in a thing — for "By person".
    public static func groups(_ items: [Item], sort: Sort, people: (Item) -> [String] = { _ in [] }) -> [Group] {
        switch sort {
        case .newest, .oldest:
            let ordered = items.sorted { sort == .newest ? $0.date > $1.date : $0.date < $1.date }
            var groups: [Group] = []
            for item in ordered {
                let title = item.date == .distantPast ? "Without a day" : month.string(from: item.date)
                if groups.last?.title == title { groups[groups.count - 1].items.append(item) } else { groups.append(Group(title: title, items: [item])) }
            }
            return groups
        case .byKind:
            let order = ["Mail", "Files from mail", "Scans and files of your own", "Links"]
            return Dictionary(grouping: items, by: \.kindName)
                .map { Group(title: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
                .sorted { (order.firstIndex(of: $0.title) ?? 9) < (order.firstIndex(of: $1.title) ?? 9) }
        case .byPerson:
            var under: [String: [Item]] = [:]
            var named: [String: [String]] = [:]
            for item in items {
                let names = people(item)
                named[item.id] = names
                for name in names.isEmpty ? ["Nobody named"] : names { under[name, default: []].append(item) }
            }
            return under
                .map { name, items in
                    var group = Group(title: name, items: items.sorted { $0.date > $1.date })
                    for item in items { let others = (named[item.id] ?? []).filter { $0 != name }; if !others.isEmpty { group.also[item.id] = others } }
                    return group
                }
                .sorted { a, b in
                    if (a.title == "Nobody named") != (b.title == "Nobody named") { return b.title == "Nobody named" }
                    return a.items.count != b.items.count ? a.items.count > b.items.count : a.title < b.title
                }
        }
    }

    /// Everyone a mail names: who wrote it, who it went to, and every person of the matter whose
    /// name is in its subject, its digest or its kept words. `text` gives a mail's kept words —
    /// the same on every device.
    public static func people(in entry: Entry, of matter: Matter, text: (Entry) -> Email?) -> [Party] {
        let parties = matter.parties
        var found: [Party] = []
        func add(_ party: Party?) { if let party, !found.contains(where: { $0 === party }) { found.append(party) } }
        add(matter.writer(entry.from))
        let kept = text(entry)
        for address in (kept?.to ?? []) + (kept?.cc ?? []) { add(matter.writer(address)) }
        let words = [entry.title, entry.digest ?? "", kept?.body ?? ""].joined(separator: "\n")
        for party in parties where !found.contains(where: { $0 === party }) {
            if ([party.name] + party.spellings).contains(where: { names(words, $0) }) { add(party) }
        }
        return found
    }

    /// Whether a text names someone by one of their spellings, as a whole word — "Helga Voss",
    /// not "Helgas" inside another word. Spellings shorter than four letters are not looked for.
    static func names(_ text: String, _ spelling: String) -> Bool {
        let spelling = spelling.trimmingCharacters(in: .whitespacesAndNewlines)
        guard spelling.count >= 4 else { return false }
        var start = text.startIndex
        while let found = text.range(of: spelling, options: [.caseInsensitive, .diacriticInsensitive], range: start..<text.endIndex) {
            let before = found.lowerBound == text.startIndex ? nil : text[text.index(before: found.lowerBound)]
            let after = found.upperBound == text.endIndex ? nil : text[found.upperBound]
            if !(before?.isLetter ?? false), !(after?.isLetter ?? false) { return true }
            start = found.upperBound
        }
        return false
    }
}
