import CryptoKit
import Foundation

/// The two things Matterbee writes to a mailbox, each on the owner's click: a draft, into the
/// Drafts folder, and a paper document the owner scanned (a letter, a contract, a bill), into the
/// Matterbee label, so it lives in the mail like any attachment and every device opens it from
/// there. It never sends — IMAP cannot send mail — and it can do nothing else.
///
/// It is not the reading client with one more command allowed. It is its own connection with its
/// own short list: log in, find the one folder, `APPEND` one message into that folder and no
/// other, log out. `IMAPClient` still cannot send `APPEND` at all, so nothing that reads mail can
/// write any.
public actor DraftDoor {
    public static let allowed: Set<String> = ["CAPABILITY", "LOGIN", "AUTHENTICATE", "LIST", "APPEND", "LOGOUT"]

    public enum Failure: Error, CustomStringConvertible {
        case noDraftsFolder
        case noLabel(String)
        public var description: String {
            switch self {
            case .noDraftsFolder: "The mailbox has no folder marked as Drafts."
            case .noLabel(let label): "The mailbox has no label or folder called “\(label)”."
            }
        }
    }

    private let transport: any IMAPTransport
    private var reader = IMAPReader()
    private var counter = 0

    public init(transport: any IMAPTransport) {
        self.transport = transport
    }

    /// Connects, puts the draft into the Drafts folder, and logs out. Says which folder.
    public static func put(_ message: Data, account: MailAccount, password: String) async throws -> String {
        let transport = TLSTransport(host: account.host, port: account.port)
        try await transport.open()
        let door = DraftDoor(transport: transport)
        do {
            try await door.start(user: account.user, password: password, google: account.usesGoogle)
            let folder = try await door.put(message)
            await door.logout()
            return folder
        } catch {
            await door.logout()
            throw error
        }
    }

    /// Connects, puts the scanned document into the label, and logs out. Says which folder.
    public static func putScan(_ message: Data, label: String, account: MailAccount, password: String) async throws -> String {
        let transport = TLSTransport(host: account.host, port: account.port)
        try await transport.open()
        let door = DraftDoor(transport: transport)
        do {
            try await door.start(user: account.user, password: password, google: account.usesGoogle)
            let folder = try await door.put(message, intoLabel: label)
            await door.logout()
            return folder
        } catch {
            await door.logout()
            throw error
        }
    }

    /// `google`: `password` is a Google token, sent with `AUTHENTICATE XOAUTH2`.
    public func start(user: String, password: String, google: Bool = false) async throws {
        let greeting = try await nextResponse()
        guard greeting.text.uppercased().hasPrefix("* OK") else { throw IMAPError.unexpected(greeting.text) }
        if google {
            _ = try await command("AUTHENTICATE", "XOAUTH2 " + GoogleSignIn.xoauth2(user: user, token: password))
            return
        }
        guard let secret = try? IMAPClient.quoted(password) else { throw IMAPError.unsafeArgument("the password") }
        _ = try await command("LOGIN", "\(try IMAPClient.quoted(user)) \(secret)")
    }

    /// Into the folder the server marks `\Drafts` — `[Gmail]/Entwürfe` on a German Gmail — and
    /// flagged `\Draft`, so every mail program shows it as one.
    public func put(_ message: Data) async throws -> String {
        let folders = try await command("LIST", "\"\" \"*\"").compactMap { response -> MailFolder? in
            let tokens = response.tokens
            guard tokens.count >= 4, tokens[0].text?.uppercased() == "LIST",
                  case .list(let flags) = tokens[1], let name = tokens[3].text else { return nil }
            return MailFolder(name: MailboxName.decode(name), attributes: Set(flags.compactMap(\.text)))
        }
        guard let drafts = folders.first(where: { $0.attributes.contains("\\drafts") }) else { throw Failure.noDraftsFolder }
        _ = try await command("APPEND", "\(try IMAPClient.quoted(MailboxName.encode(drafts.name))) (\\Draft)", literal: message)
        return drafts.name
    }

    /// Into the label and no other folder — found by its name, as the daily door finds it — and
    /// flagged `\\Seen`: the owner put it there, there is nothing to read. No label, no scan.
    public func put(_ message: Data, intoLabel label: String) async throws -> String {
        let folders = try await command("LIST", "\"\" \"*\"").compactMap { response -> MailFolder? in
            let tokens = response.tokens
            guard tokens.count >= 4, tokens[0].text?.uppercased() == "LIST",
                  case .list(let flags) = tokens[1], let name = tokens[3].text else { return nil }
            return MailFolder(name: MailboxName.decode(name), attributes: Set(flags.compactMap(\.text)))
        }
        guard let folder = folders.first(where: { $0.name == label }) ?? folders.first(where: { $0.name.lowercased() == label.lowercased() }),
              !folder.attributes.contains("\\noselect") else { throw Failure.noLabel(label) }
        _ = try await command("APPEND", "\(try IMAPClient.quoted(MailboxName.encode(folder.name))) (\\Seen)", literal: message)
        return folder.name
    }

    public func logout() async {
        _ = try? await command("LOGOUT", "")
        await transport.close()
    }

    private func command(_ verb: String, _ arguments: String, literal: Data? = nil) async throws -> [IMAPResponse] {
        guard Self.allowed.contains(verb) else { throw IMAPError.notReadOnly(verb) }
        // APPEND carries a message, and nothing else ever does.
        guard (verb == "APPEND") == (literal != nil) else { throw IMAPError.notReadOnly(verb) }
        counter += 1
        let tag = "D\(counter)"
        var line = arguments.isEmpty ? "\(tag) \(verb)" : "\(tag) \(verb) \(arguments)"
        if let literal { line += " {\(literal.count)}" }
        try await transport.send(Data((line + "\r\n").utf8))
        if let literal {
            // The server says "+ go on" before it takes the message.
            let ready = try await nextResponse()
            guard ready.text.hasPrefix("+") else {
                throw IMAPError.refused(command: verb, answer: ready.text)
            }
            try await transport.send(literal + Data("\r\n".utf8))
        }
        var untagged: [IMAPResponse] = []
        while true {
            let response = try await nextResponse()
            if let status = response.status(tag: tag) {
                guard status.ok else { throw IMAPError.refused(command: verb, answer: status.rest) }
                return untagged
            }
            if verb == "AUTHENTICATE", response.text.hasPrefix("+") {
                try await transport.send(Data("\r\n".utf8))
                continue
            }
            untagged.append(response)
        }
    }

    private func nextResponse() async throws -> IMAPResponse {
        while true {
            if let response = reader.next() { return response }
            let data = try await transport.receive()
            guard !data.isEmpty else { throw IMAPError.closed }
            reader.append(data)
        }
    }
}

/// A draft as a mail program writes one: plain text in UTF-8, headers encoded where they need
/// it, and — when it answers a mail — `In-Reply-To` and `References`, so Gmail files it in that
/// conversation.
public struct DraftMessage: Sendable {
    public var from: String
    public var to: (name: String?, address: String)?
    public var subject: String
    public var body: String
    public var replyingTo: String?
    public var date: Date

    public init(from: String, to: (name: String?, address: String)?, subject: String, body: String,
                replyingTo: String? = nil, date: Date = Date()) {
        self.from = from
        self.to = to
        self.subject = subject
        self.body = body
        self.replyingTo = replyingTo
        self.date = date
    }

    /// `=?UTF-8?B?…?=` when the words are not plain ASCII.
    static func header(_ text: String) -> String {
        guard !text.allSatisfy({ $0.isASCII && !$0.isNewline }) else { return text }
        return "=?UTF-8?B?" + Data(text.replacingOccurrences(of: "\n", with: " ").utf8).base64EncodedString() + "?="
    }

    public var data: Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let domain = from.split(separator: "@").last.map(String.init) ?? "matterbee.local"
        let id = SHA256.hash(data: Data((subject + body + "\(date.timeIntervalSince1970)").utf8)).prefix(12)
            .map { String(format: "%02x", $0) }.joined()
        var lines = ["From: \(from)"]
        if let to {
            lines.append("To: " + (to.name.map { "\(Self.header($0)) <\(to.address)>" } ?? to.address))
        }
        lines.append("Subject: \(Self.header(subject))")
        lines.append("Date: \(formatter.string(from: date))")
        lines.append("Message-ID: <matterbee.\(id)@\(domain)>")
        if let reply = replyingTo {
            lines.append("In-Reply-To: <\(reply)>")
            lines.append("References: <\(reply)>")
        }
        lines += ["MIME-Version: 1.0", "Content-Type: text/plain; charset=utf-8", "Content-Transfer-Encoding: base64"]
        let encoded = Data(body.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n").utf8)
            .base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n" + encoded).utf8)
    }
}

/// A paper document, scanned — a letter, a contract, a bill: a mail from the owner to the owner, with the scan
/// attached and the matter named in the subject, so the Mac's next "Get new mail" reads it and
/// files it where it belongs — its tasks and dates too — like any mail under the label.
public struct ScanMessage: Sendable {
    public var owner: String
    public var title: String
    public var matter: String?
    public var file: (name: String, contentType: String, data: Data)
    public var date: Date

    public init(owner: String, title: String, matter: String?, file: (name: String, contentType: String, data: Data), date: Date = Date()) {
        self.owner = owner
        self.title = title
        self.matter = matter
        self.file = file
        self.date = date
    }

    public var subject: String { "Document: " + title + (matter.map { " — for “\($0)”" } ?? "") }

    /// Its own Message-ID, from the file and the moment: the same scan put in twice is two mails.
    public var messageID: String {
        let domain = owner.split(separator: "@").last.map(String.init) ?? "matterbee.local"
        let id = SHA256.hash(data: file.data + Data("\(date.timeIntervalSince1970)".utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return "matterbee.scan.\(id)@\(domain)"
    }

    public var data: Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let boundary = "matterbee-" + messageID.prefix(24).filter(\.isLetter)
        let text = ["A paper document, scanned and kept by Matterbee" + (matter.map { " for “\($0)”" } ?? "") + ".",
                    "What it is: \(title)", "The scan is attached: \(file.name)"].joined(separator: "\n")
        func encoded(_ data: Data) -> String {
            data.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
        }
        let name = DraftMessage.header(file.name)
        let lines = [
            "From: \(owner)", "To: \(owner)", "Subject: \(DraftMessage.header(subject))", "Date: \(formatter.string(from: date))",
            "Message-ID: <\(messageID)>", "X-Matterbee: scan", "MIME-Version: 1.0",
            "Content-Type: multipart/mixed; boundary=\"\(boundary)\"", "",
            "--\(boundary)", "Content-Type: text/plain; charset=utf-8", "Content-Transfer-Encoding: base64", "",
            encoded(Data(text.replacingOccurrences(of: "\n", with: "\r\n").utf8)),
            "--\(boundary)", "Content-Type: \(file.contentType); name=\"\(name)\"", "Content-Transfer-Encoding: base64",
            "Content-Disposition: attachment; filename=\"\(name)\"", "",
            encoded(file.data),
            "--\(boundary)--", "",
        ]
        return Data(lines.joined(separator: "\r\n").utf8)
    }
}
