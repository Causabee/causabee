import Foundation

/// The manual edition's daily door: every mail under one label, and the replies that came after
/// it without one.
///
/// A thread is labelled once, not once per reply. Gmail puts a label on the messages of a
/// conversation as it is then; a reply that arrives next week does not get it. So after the
/// labelled mail is read, the replies are looked for where all mail is — Gmail's All Mail, or
/// the inbox and sent folder elsewhere — by the thread Gmail already knows (`X-GM-THRID`), or
/// by `References` and `In-Reply-To` on servers that do not say. A reply that shares only a
/// subject is not fetched: `Re: Termin` could be anybody's.
///
/// Nothing is written anywhere. The mail is read, turned into `Email` values in memory, and
/// each one points back at where it lives (`imap://host/folder;UIDVALIDITY=…/;UID=…`).
public struct LabelIntake: Sendable {
    public var label: String
    public var since: Date?
    /// For the pointer back to each mail.
    public var host: String
    /// Replies of replies, when the server has no thread of its own to ask for.
    public var maxRounds = 5
    /// Message-IDs already read and answered. Their mail is not downloaded again: only its
    /// Message-ID is asked for, to know it is there, and its thread to find the replies.
    public var known: Set<String> = []
    /// A scan mailed from anywhere — a scanner app, the share sheet — with this word in the
    /// subject counts as labelled, label or not. Only mail the owner sent to the owner: mail
    /// about Matterbee from anyone else, or to anyone else, is not the owner's paper.
    public var keyword: String?
    public var ownAddresses: [String] = []
    static let batch = 25

    public init(label: String, since: Date? = nil, host: String, known: Set<String> = []) {
        self.label = label
        self.since = since
        self.host = host
        self.known = known
    }

    public struct Result: Sendable {
        public var emails: [Email] = []
        /// The Message-IDs of the mail the owner labelled: the bulk filter does not overrule these.
        public var labelled: Set<String> = []
        /// Mail that came in by thread, and how it was found.
        public var followed: [String: Way] = [:]
        public var labelFolder: OpenedFolder?
        /// Where replies were looked for.
        public var searched: [String] = []
        /// Labelled mail that was known already, so not downloaded.
        public var alreadyKnown = 0
    }

    public enum Way: String, Sendable {
        case gmailThread = "Gmail thread"
        case references = "References / In-Reply-To"
    }

    public enum Failure: Error, CustomStringConvertible {
        case noSuchLabel(String, available: [String])
        public var description: String {
            switch self {
            case .noSuchLabel(let label, let available):
                "there is no label or folder called \"\(label)\". The account has:\n" +
                available.map { "  \($0)" }.joined(separator: "\n")
            }
        }
    }

    public func run(_ mailbox: some ReadOnlyMailbox, progress: @Sendable (String) -> Void = { _ in }) async throws -> Result {
        var result = Result()
        let folders = try await mailbox.folders()
        guard let folder = folders.first(where: { $0.name == label })
                ?? folders.first(where: { $0.name.lowercased() == label.lowercased() }) else {
            throw Failure.noSuchLabel(label, available: folders.filter { !$0.attributes.contains("\\noselect") }.map(\.name))
        }
        let gmail = await mailbox.isGmail
        let window: [SearchKey] = since.map { [.since($0)] } ?? []

        // The labelled mail.
        let opened = try await mailbox.examine(folder.name)
        result.labelFolder = opened
        let uids = try await mailbox.search(window.isEmpty ? [.all] : window)
        progress("\(folder.name): \(uids.count) labelled")
        var threads: [String] = []
        // The Message-ID and the thread of every labelled mail first — a few bytes each — and the
        // whole mail only for what is not known yet.
        var wanted: [UInt32] = []
        var labelledIDs: [String] = []
        for chunk in uids.chunked(Self.batch) {
            for message in try await mailbox.fetch(Array(chunk), .messageID) {
                if let thread = message.gmailThread, !threads.contains(thread) { threads.append(thread) }
                let id = Self.messageID(in: message)
                if let id { labelledIDs.append(id) }
                if let id, known.contains(id) { result.alreadyKnown += 1 } else { wanted.append(message.uid) }
            }
        }
        for message in try await fetchWhole(wanted, from: mailbox) {
            let email = parse(message, in: opened)
            guard result.labelled.insert(email.id).inserted else { continue }
            result.emails.append(email)
            if let thread = message.gmailThread, !threads.contains(thread) { threads.append(thread) }
        }

        let everything = (folders.first { $0.attributes.contains("\\all") }.map { [$0.name] }
            ?? folders.filter { $0.name.uppercased() == "INBOX" || $0.attributes.contains("\\sent") }.map(\.name))
            .filter { $0 != folder.name }
        // Scans the owner mailed to themselves with the keyword: as if labelled.
        if let keyword, !keyword.isEmpty, !ownAddresses.isEmpty {
            var mine = Set(labelledIDs).union(result.labelled)
            var found = 0
            for name in everything {
                let opened = try await mailbox.examine(name)
                var candidates: [UInt32] = []
                for from in ownAddresses {
                    for to in ownAddresses { candidates += try await mailbox.search(window + [.subject(keyword), .from(from), .to(to)]) }
                }
                var wanted: [UInt32] = []
                for chunk in Array(Set(candidates)).sorted().chunked(Self.batch) {
                    for message in try await mailbox.fetch(Array(chunk), .messageID) {
                        let id = Self.messageID(in: message)
                        if let id, mine.contains(id) { continue }
                        if let id, known.contains(id) { mine.insert(id); labelledIDs.append(id); result.alreadyKnown += 1; continue }
                        wanted.append(message.uid)
                    }
                }
                for message in try await fetchWhole(wanted, from: mailbox) {
                    let email = parse(message, in: opened)
                    guard mine.insert(email.id).inserted else { continue }
                    result.labelled.insert(email.id)
                    result.emails.append(email)
                    found += 1
                    if let thread = message.gmailThread, !threads.contains(thread) { threads.append(thread) }
                }
            }
            if found > 0 { progress("\(found) mailed to yourself with “\(keyword)” in the subject") }
        }
        // The replies that followed it.
        result.searched = everything
        var known = Set(result.emails.map(\.id)).union(self.known).union(labelledIDs)
        var tried: [String: Set<UInt32>] = [:]

        if gmail, !threads.isEmpty {
            for name in everything {
                let opened = try await mailbox.examine(name)
                var candidates: [UInt32] = []
                for thread in threads { candidates += try await mailbox.search(window + [.gmailThread(thread)]) }
                let added = try await fetchNew(candidates, from: mailbox, in: opened, known: &known, tried: &tried[name, default: []])
                for email in added { result.followed[email.id] = .gmailThread }
                result.emails += added
            }
        } else {
            // Round by round across every folder, because a thread goes back and forth between
            // them: the owner's answer is in Sent, and the answer to that is in the inbox.
            var frontier = Array(Set(result.emails.map(\.id) + labelledIDs))
            for _ in 0..<maxRounds where !frontier.isEmpty {
                var round: [Email] = []
                for name in everything {
                    let opened = try await mailbox.examine(name)
                    var candidates: [UInt32] = []
                    for id in frontier { candidates += try await mailbox.search(window + [.replies(to: id)]) }
                    round += try await fetchNew(candidates, from: mailbox, in: opened, known: &known, tried: &tried[name, default: []])
                }
                for email in round { result.followed[email.id] = .references }
                result.emails += round
                frontier = round.map(\.id)
            }
        }
        progress("\(everything.joined(separator: ", ")): \(result.followed.count) followed by thread")

        result.emails.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        return result
    }

    /// Asks for the Message-ID first and the whole mail only when it is one not yet read: All
    /// Mail holds the labelled mail too, and reading every PDF twice is not free.
    private func fetchNew(_ candidates: [UInt32], from mailbox: some ReadOnlyMailbox, in folder: OpenedFolder,
                          known: inout Set<String>, tried: inout Set<UInt32>) async throws -> [Email] {
        var seen = Set<UInt32>()
        let fresh = candidates.filter { !tried.contains($0) && seen.insert($0).inserted }
        tried.formUnion(fresh)
        var wanted: [UInt32] = []
        for chunk in fresh.chunked(Self.batch) {
            for message in try await mailbox.fetch(Array(chunk), .messageID) {
                if let id = Self.messageID(in: message), known.contains(id) { continue }
                wanted.append(message.uid)
            }
        }
        var added: [Email] = []
        for message in try await fetchWhole(wanted, from: mailbox) {
            let email = parse(message, in: folder)
            if known.insert(email.id).inserted { added.append(email) }
        }
        return added
    }

    static func messageID(in message: FetchedMessage) -> String? {
        let headers = EMLParser.parseHeaders(IMAPReader.string(message.data).replacingOccurrences(of: "\r\n", with: "\n"))
        let id = headers["message-id"]?.first?.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
        return id?.isEmpty == false ? id : nil
    }

    private func fetchWhole(_ uids: [UInt32], from mailbox: some ReadOnlyMailbox) async throws -> [FetchedMessage] {
        var out: [FetchedMessage] = []
        for chunk in uids.chunked(Self.batch) { out += try await mailbox.fetch(Array(chunk), .whole) }
        return out
    }

    func parse(_ message: FetchedMessage, in folder: OpenedFolder) -> Email {
        EMLParser.parse(data: message.data, url: pointer(to: message.uid, in: folder))
    }

    /// RFC 5092's form. Says where the mail is without holding any of it.
    func pointer(to uid: UInt32, in folder: OpenedFolder) -> URL {
        let path = folder.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: ";"))) ?? folder.name
        return URL(string: "imap://\(host)/\(path);UIDVALIDITY=\(folder.uidValidity)/;UID=\(uid)")
            ?? URL(string: "imap://\(host)/")!
    }
}

extension Array {
    func chunked(_ size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: size).map { self[$0..<Swift.min($0 + size, count)] }
    }
}
