import Foundation

/// A matter's mails as conversations: each thread starts with its first mail, and every reply
/// sits under the mail it answers. Who answers whom comes from the headers (`In-Reply-To`,
/// `References`); a reply whose mail is not in the matter joins the thread of its subject.
public enum MailThreads {
    public struct Thread: Identifiable {
        public var id: String { root.entry.messageID.isEmpty ? "\(ObjectIdentifier(root.entry))" : root.entry.messageID }
        public var root: Node
        /// The subject without "Re:" and "AW:".
        public var subject: String
        public var count: Int
        public var first: Date?
        public var last: Date?
        /// Everyone who wrote in it, in the order they first did.
        public var senders: [String]
        /// The mails top to bottom, each with how far in it goes and which lines lead past it.
        public var rows: [Row] { var rows: [Row] = []; Self.flatten(root, depth: 0, rails: [], isLast: true, into: &rows); return rows }

        static func flatten(_ node: Node, depth: Int, rails: [Bool], isLast: Bool, into rows: inout [Row]) {
            rows.append(Row(entry: node.entry, depth: depth, rails: rails, isLast: isLast))
            for (index, child) in node.children.enumerated() {
                let last = index == node.children.count - 1
                // Below the top mail, the line of this level runs on past its children while
                // more of its siblings follow.
                flatten(child, depth: depth + 1, rails: depth == 0 ? [] : rails + [!isLast], isLast: last, into: &rows)
            }
        }
    }

    public struct Node {
        public var entry: Entry
        public var children: [Node]
    }

    /// The rows whose line goes on down into the next: a reply shown at the deepest indent that is
    /// itself answered. Its answer cannot step further in and stands under it at the same indent —
    /// the line between them says it belongs there, where two corners with a gap looked like two
    /// replies to the mail above.
    public static func joined(_ rows: [Row], deepest: Int) -> Set<ObjectIdentifier> {
        var joined: Set<ObjectIdentifier> = []
        for (row, next) in zip(rows, rows.dropFirst()) where row.depth >= deepest && next.depth > row.depth {
            joined.insert(row.id)
        }
        return joined
    }

    public struct Row: Identifiable {
        public var id: ObjectIdentifier { ObjectIdentifier(entry) }
        public var entry: Entry
        /// 0 for the first mail, 1 for a reply to it, 2 for a reply to that reply …
        public var depth: Int
        /// For each level between the top and this row's own: whether its line goes on past it.
        public var rails: [Bool]
        /// The last reply to its mail: its line stops here.
        public var isLast: Bool
    }

    /// Newest conversation first; inside one, the first mail on top and replies by date.
    public static func build(_ entries: [Entry]) -> [Thread] {
        let byDate = entries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        var byID: [String: Entry] = [:]
        for entry in byDate where !entry.messageID.isEmpty && byID[entry.messageID] == nil { byID[entry.messageID] = entry }

        var parent: [ObjectIdentifier: Entry] = [:]
        for entry in byDate {
            guard let id = entry.replyTo, !id.isEmpty, id != entry.messageID, let answered = byID[id],
                  // A reply comes after the mail it answers.
                  (answered.date ?? .distantPast) <= (entry.date ?? .distantFuture) else { continue }
            // Never a loop: a mail cannot sit under one that sits under it.
            var up: Entry? = answered, safe = true
            while let step = up { if step === entry { safe = false; break }; up = parent[ObjectIdentifier(step)] }
            if safe { parent[ObjectIdentifier(entry)] = answered }
        }

        // A mail answering one that is not here joins the first mail of the same subject.
        var firstOfSubject: [String: Entry] = [:]
        for entry in byDate where parent[ObjectIdentifier(entry)] == nil {
            let key = ThreadMemory.subjectKey(entry.title) ?? ""
            if let earlier = firstOfSubject[key], !key.isEmpty {
                parent[ObjectIdentifier(entry)] = earlier
            } else {
                firstOfSubject[key] = entry
            }
        }

        var children: [ObjectIdentifier: [Entry]] = [:]
        for entry in byDate { if let up = parent[ObjectIdentifier(entry)] { children[ObjectIdentifier(up), default: []].append(entry) } }
        func node(_ entry: Entry) -> Node { Node(entry: entry, children: (children[ObjectIdentifier(entry)] ?? []).map(node)) }

        let threads = byDate.filter { parent[ObjectIdentifier($0)] == nil }.map { root -> Thread in
            var all: [Entry] = []
            func collect(_ node: Node) { all.append(node.entry); node.children.forEach(collect) }
            let tree = node(root)
            collect(tree)
            var senders: [String] = []
            for entry in all.sorted(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) {
                let name = entry.matter?.writerName(entry.from) ?? Email.displayName(in: entry.from) ?? Email.address(in: entry.from)
                if !name.isEmpty, !senders.contains(name) { senders.append(name) }
            }
            let dates = all.compactMap(\.date)
            return Thread(root: tree, subject: clean(root.title), count: all.count, first: dates.min(), last: dates.max(), senders: senders)
        }
        return threads.sorted { ($0.last ?? .distantPast) > ($1.last ?? .distantPast) }
    }

    /// "Re: AW: SperrMüll" → "SperrMüll", written as it was.
    public static func clean(_ subject: String) -> String {
        var text = subject.trimmingCharacters(in: .whitespaces)
        while let prefix = text.firstMatch(of: /^(?i:re|aw|antw|wg|fwd?)\s*:\s*/), !prefix.output.isEmpty {
            text = String(text[prefix.range.upperBound...])
        }
        return text.isEmpty ? subject : text
    }
}

extension MailFetch {
    /// For each mail, the Message-ID it answers ("" for none), read from the headers only —
    /// one fetch per folder, read-only. Mails the folder no longer has are left out.
    public static func replyLinks(of mails: [(pointer: String, messageID: String)],
                                  from mailbox: some ReadOnlyMailbox) async throws -> [String: String] {
        var byFolder: [String: (validity: UInt32, uids: [UInt32: String])] = [:]
        for mail in mails {
            guard let (folder, validity, uid) = parse(mail.pointer) else { continue }
            byFolder[folder, default: (validity, [:])].uids[uid] = mail.messageID
        }
        var links: [String: String] = [:]
        for (folder, wanted) in byFolder {
            guard let opened = try? await mailbox.examine(folder), opened.uidValidity == wanted.validity else { continue }
            for fetched in try await mailbox.fetch(Array(wanted.uids.keys).sorted(), .threading) {
                let email = EMLParser.parse(data: fetched.data, url: URL(fileURLWithPath: "/"))
                guard let id = wanted.uids[fetched.uid], email.id == id else { continue }
                links[id] = ThreadMemory.parents(of: email).last ?? ""
            }
        }
        return links
    }
}
