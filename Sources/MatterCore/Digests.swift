import CryptoKit
import Foundation
import NaturalLanguage
import SwiftData

/// A mail's own words, kept on this Mac only, beside the store — never in the store, which is
/// what will sync. Read once from the mail server, so it need not be read there again.
public enum MailText {
    public static func folder(besides store: URL) -> URL {
        store.deletingLastPathComponent().appendingPathComponent("Mail-Text", isDirectory: true)
    }

    static func url(for messageID: String, besides store: URL) -> URL {
        let name = SHA256.hash(data: Data(messageID.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return folder(besides: store).appendingPathComponent(name + ".txt")
    }

    /// The kept words of one mail or file, gone: the assistant reads them no more.
    public static func forget(_ messageID: String, besides store: URL) {
        try? FileManager.default.removeItem(at: url(for: messageID, besides: store))
    }

    public static func save(_ email: Email, besides store: URL) {
        guard !email.id.isEmpty else { return }
        var lines = ["From: \(email.from)"]
        if !email.to.isEmpty { lines.append("To: \(email.to.joined(separator: ", "))") }
        if let date = email.date { lines.append("Date: \(ISO8601DateFormatter().string(from: date))") }
        lines.append("Subject: \(email.subject)")
        let text = lines.joined(separator: "\n") + "\n\n" + email.body
        try? FileManager.default.createDirectory(at: folder(besides: store), withIntermediateDirectories: true)
        try? text.write(to: url(for: email.id, besides: store), atomically: true, encoding: .utf8)
    }

    /// The mail as it was kept: its headers and its words, enough to disguise and read it again.
    public static func load(_ messageID: String, besides store: URL) -> Email? {
        guard let text = try? String(contentsOf: url(for: messageID, besides: store), encoding: .utf8),
              let split = text.range(of: "\n\n") else { return nil }
        var header: [String: String] = [:]
        for line in text[..<split.lowerBound].split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            header[String(line[..<colon])] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        let subject = header["Subject"] ?? ""
        return Email(source: url(for: messageID, besides: store), id: messageID, headers: ["subject": [subject]], subject: subject,
                     from: header["From"] ?? "", to: (header["To"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                     cc: [], date: header["Date"].flatMap { ISO8601DateFormatter().date(from: $0) },
                     body: String(text[split.upperBound...]), attachments: [])
    }

    public static func has(_ messageID: String, besides store: URL) -> Bool {
        FileManager.default.fileExists(atPath: url(for: messageID, besides: store).path)
    }
}

/// Digests for mail sorted in before the extraction wrote them: each mail read again from the
/// server, read-only, disguised like any mail, and sent with nothing but the digest to write.
public enum DigestPrompt {
    public static let version = "digest-v3"

    public static let system = """
    You are given one email, disguised: people, companies, places and numbers are placeholders \
    such as [Person A]. Use them exactly as written. Write its `digest` in the same language as \
    the email's own words — an English email gets an English digest, a German one a German \
    digest; never translate. Two or three short sentences on what this email itself says — what it tells or asks, with the \
    details someone would look up months later: amounts, numbers of things, what was agreed, \
    what an attachment is, what someone promised. Not who sent it or when: those are known. \
    Null for an email with nothing worth keeping, such as an automatic confirmation.
    """

    public static var schema: [String: Any] {
        ["type": "object", "properties": ["digest": ["anyOf": [["type": "string"], ["type": "null"]]]],
         "required": ["digest"], "additionalProperties": false]
    }

    struct Reply: Codable { var digest: String? }
}

@MainActor
public enum DigestBackfill {
    /// Mail of the label with no digest yet.
    public static func missing(in context: ModelContext) -> [Entry] {
        ((try? context.fetch(FetchDescriptor<Entry>())) ?? [])
            // An empty digest is an answer: the mail had nothing worth keeping. Nil is not asked yet.
            .filter { $0.digest == nil && !$0.messageID.isEmpty && $0.source.pointer.hasPrefix("imap://") }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    /// Mail whose digest is in another language than the mail itself — from before the digest
    /// followed the mail's language. Told apart by the mail's own words, kept on the Mac.
    public static func inAnotherLanguage(in context: ModelContext, store: URL) -> [Entry] {
        ((try? context.fetch(FetchDescriptor<Entry>())) ?? []).filter { entry in
            guard let digest = entry.digest, !digest.isEmpty,
                  let text = try? String(contentsOf: MailText.url(for: entry.messageID, besides: store), encoding: .utf8) else { return false }
            let whole = text.components(separatedBy: "\n\n").dropFirst().joined(separator: "\n\n")
            let newest = Quotes.newest(of: whole, subject: entry.title).newest
            // "CC vergessen" above a forwarded mail says nothing about its language.
            return language(of: newest.count >= 200 ? newest : whole) != language(of: digest)
        }
    }

    static func language(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(1_500)))
        return recognizer.dominantLanguage?.rawValue
    }

    /// Exactly what would be sent for a mail kept on the Mac, disguised — to look at, not to send.
    public static func preview(_ entry: Entry, store: URL, mapping url: URL) -> String? {
        var mapping = Pseudonymizer.Mapping()
        if let data = try? Data(contentsOf: url) { mapping = (try? JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data)) ?? mapping }
        _ = mapping.upgrade()
        guard let email = MailText.load(entry.messageID, besides: store) else { return nil }
        return prepared(email, entries: mapping.placeholder)?.text
    }

    static func prepared(_ email: Email, entries: [Pseudonymizer.Entry]) -> (text: String, pseudonymizer: Pseudonymizer)? {
        let report = Spike(detector: EntityDetector())
            .run(emails: [email], labelled: [email.id], pseudonymizer: Pseudonymizer(mode: .placeholder, entries: entries))
        guard let disguise = report.outcomes.first?.judgement.disguise, let pseudonymizer = report.pseudonymizer else { return nil }
        let newest = Quotes.newest(of: disguise.body, subject: disguise.subject)
        let sent = email.date.map { "Sent on \(MatterStatus.day($0)).\n\n" } ?? ""
        return (sent + Extractor.text(of: disguise, body: newest.newest, omitted: newest.omitted), pseudonymizer)
    }

    /// One mail and a short answer: about 2,000 tokens in, 150 out.
    public static func estimate(_ count: Int, model: Claude.Model) -> Double {
        Double(count) * model.cost(input: 2_000, output: 150) * 1.1
    }

    public struct Result: Sendable {
        public var written = 0
        public var empty = 0
        public var gone = 0
        public var cost = 0.0
    }

    /// Reads each mail again over one connection, keeps its text on the Mac, and asks for its
    /// digest. The mapping learns any name it had not seen, and is written back.
    public static func run(_ entries: [Entry], account: MailAccount, password: String, store: URL, mapping url: URL,
                           claude: Claude, model: Claude.Model, context: ModelContext,
                           progress: (Int, Int) -> Void = { _, _ in }) async throws -> Result {
        var mapping = Pseudonymizer.Mapping()
        if let data = try? Data(contentsOf: url) { mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data) }
        _ = mapping.upgrade()
        var entriesKnown = mapping.placeholder
        // The mail server only for a mail whose words are not kept on the Mac yet.
        var client: IMAPClient?
        var result = Result()
        defer { if let client { Task { await client.logout() } } }
        for (index, entry) in entries.enumerated() {
            progress(index + 1, entries.count)
            let email: Email
            if let kept = MailText.load(entry.messageID, besides: store) {
                email = kept
            } else {
                if client == nil { client = try await IMAPClient.connect(to: account, password: password) }
                guard let client, let data = try? await MailFetch.message(pointer: entry.source.pointer, messageID: entry.messageID, from: client) else {
                    result.gone += 1
                    continue
                }
                email = EMLParser.parse(data: data, url: URL(string: entry.source.pointer) ?? URL(fileURLWithPath: "/"))
                MailText.save(email, besides: store)
            }
            guard let (text, pseudonymizer) = prepared(email, entries: entriesKnown) else { continue }
            entriesKnown = pseudonymizer.entries
            let body = Claude.body(model: model, system: DigestPrompt.system, user: text, schema: DigestPrompt.schema, effort: "low")
            let answer = try await claude.send(body, model: model)
            result.cost += answer.cost
            let reply = try JSONDecoder().decode(DigestPrompt.Reply.self, from: answer.json)
            if let digest = reply.digest.map({ pseudonymizer.restorer.apply($0).text }), !digest.isEmpty {
                entry.digest = digest
                result.written += 1
            } else {
                entry.digest = ""
                result.empty += 1
            }
            if index % 10 == 9 { try? context.save() }
        }
        try context.save()
        mapping.placeholder = entriesKnown
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(mapping).write(to: url, options: .atomic)
        return result
    }
}
