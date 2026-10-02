import Foundation

/// Where the bytes go. The real one is a TLS connection; a test gives it a script.
public protocol IMAPTransport: Sendable {
    func send(_ data: Data) async throws
    /// Some bytes, as many as have arrived. Empty means the server closed the connection.
    func receive() async throws -> Data
    func close() async
}

/// What intake needs from a mail account, and nothing more: find folders, open one, search it,
/// read from it. There is no way to change anything through this protocol, so no code written
/// against it can.
public protocol ReadOnlyMailbox: Sendable {
    /// Gmail tells a thread apart itself (`X-GM-THRID`), which is better than guessing from headers.
    var isGmail: Bool { get async }
    func folders() async throws -> [MailFolder]
    func examine(_ folder: String) async throws -> OpenedFolder
    func search(_ keys: [SearchKey]) async throws -> [UInt32]
    func fetch(_ uids: [UInt32], _ part: FetchPart) async throws -> [FetchedMessage]
}

public struct MailFolder: Sendable, Equatable {
    /// Decoded: `Verträge`, not `Vertr&AOQ-ge`.
    public var name: String
    /// Lowercased, backslash kept: `\all`, `\sent`, `\noselect`.
    public var attributes: Set<String>

    public init(name: String, attributes: Set<String> = []) {
        self.name = name
        self.attributes = Set(attributes.map { $0.lowercased() })
    }
}

public struct OpenedFolder: Sendable, Equatable {
    public var name: String
    /// A UID means the same mail only as long as this number does not change.
    public var uidValidity: UInt32
    public var exists: Int
}

public enum SearchKey: Sendable, Equatable {
    case all
    case since(Date)
    case gmailThread(String)
    /// Mail whose `References` or `In-Reply-To` names this Message-ID.
    case replies(to: String)
    /// The mail with this Message-ID.
    case messageID(String)
    /// Mail whose subject has these words in it; mail from, or to, this address.
    case subject(String)
    case from(String)
    case to(String)
    /// Mail that fits any of these: many threads or Message-IDs in one question to the server,
    /// not one round trip each.
    case any([SearchKey])
}

public enum FetchPart: Sendable {
    /// The whole message. Read with `BODY.PEEK`, which leaves it unread.
    case whole
    /// Only the `Message-ID` header, to tell a mail already read from one that is new.
    case messageID
    /// `Message-ID`, `In-Reply-To` and `References`: which mail answers which.
    case threading
}

public struct FetchedMessage: Sendable, Equatable {
    public var uid: UInt32
    public var gmailThread: String?
    public var data: Data
}

public enum IMAPError: Error, CustomStringConvertible, Equatable {
    case closed
    case refused(command: String, answer: String)
    case notReadOnly(String)
    case unexpected(String)
    case unsafeArgument(String)

    public var description: String {
        switch self {
        case .closed:
            "the mail server closed the connection"
        case .refused("LOGIN", let answer):
            "the mail server refused the login: \(answer)\n" +
            "For Gmail, use an app password (myaccount.google.com/apppasswords), not your Google password."
        case .refused(let command, let answer):
            "the mail server said no to \(command): \(answer)"
        case .notReadOnly(let command):
            "\(command) is not a command Causabee sends: it only ever reads mail"
        case .unexpected(let text):
            "the mail server answered something this reader does not understand: \(text.prefix(120))"
        case .unsafeArgument(let text):
            "cannot send \(text) to the mail server: it has a line break or a character outside ASCII"
        }
    }
}

/// A read-only IMAP client: as much of IMAP4rev1 as reading one folder needs.
///
/// Read-only is not a promise in a comment. The commands this client can send are listed in
/// `allowed`, and none of them changes a mailbox: a folder is opened with `EXAMINE`, which the
/// server itself holds to read-only, and mail is read with `BODY.PEEK[]`, which does not mark
/// it as read. `STORE`, `COPY`, `MOVE`, `EXPUNGE`, `APPEND` and `SELECT` cannot be sent at all.
public actor IMAPClient: ReadOnlyMailbox {
    public static let allowed: Set<String> = ["CAPABILITY", "LOGIN", "AUTHENTICATE", "LIST", "EXAMINE", "UID SEARCH", "UID FETCH", "NOOP", "LOGOUT"]

    private let transport: any IMAPTransport
    private var reader = IMAPReader()
    private var counter = 0
    public private(set) var capabilities: Set<String> = []

    public var isGmail: Bool { capabilities.contains("X-GM-EXT-1") }

    public init(transport: any IMAPTransport) {
        self.transport = transport
    }

    /// Reads the server's greeting and what it can do. Call once, before anything else.
    public func start() async throws {
        let greeting = try await nextResponse()
        guard greeting.text.uppercased().hasPrefix("* OK") || greeting.text.uppercased().hasPrefix("* PREAUTH") else {
            throw IMAPError.unexpected(greeting.text)
        }
        try await refreshCapabilities()
    }

    public func login(user: String, password: String) async throws {
        // The password is never repeated in an error, not even its first few letters.
        guard let secret = try? Self.quoted(password) else { throw IMAPError.unsafeArgument("the password") }
        _ = try await command("LOGIN", "\(try Self.quoted(user)) \(secret)")
        // Servers often say more about themselves once they know who is asking.
        try await refreshCapabilities()
    }

    /// Signed in with Google: `AUTHENTICATE XOAUTH2`, the token in the same line. Refused, Gmail
    /// first explains itself as a `+` line, and waits for an empty one before it says NO.
    public func authenticate(user: String, token: String) async throws {
        _ = try await command("AUTHENTICATE", "XOAUTH2 " + GoogleSignIn.xoauth2(user: user, token: token))
        try await refreshCapabilities()
    }

    public func logout() async {
        _ = try? await command("LOGOUT", "")
        await transport.close()
    }

    public func folders() async throws -> [MailFolder] {
        try await command("LIST", "\"\" \"*\"").compactMap { response in
            let tokens = response.tokens
            guard tokens.count >= 4, tokens[0].text?.uppercased() == "LIST",
                  case .list(let flags) = tokens[1], let name = tokens[3].text else { return nil }
            return MailFolder(name: MailboxName.decode(name), attributes: Set(flags.compactMap(\.text)))
        }
    }

    public func examine(_ folder: String) async throws -> OpenedFolder {
        let responses = try await command("EXAMINE", try Self.quoted(MailboxName.encode(folder)))
        var validity: UInt32 = 0
        var exists = 0
        for response in responses {
            if let match = response.text.firstMatch(of: /\[UIDVALIDITY (\d+)\]/), let number = UInt32(match.output.1) {
                validity = number
            }
            if let match = response.text.firstMatch(of: /^\* (\d+) EXISTS/), let number = Int(match.output.1) {
                exists = number
            }
        }
        return OpenedFolder(name: folder, uidValidity: validity, exists: exists)
    }

    public func search(_ keys: [SearchKey]) async throws -> [UInt32] {
        let criteria = try keys.map(Self.criterion).joined(separator: " ")
        return try await command("UID SEARCH", criteria.isEmpty ? "ALL" : criteria).flatMap { response -> [UInt32] in
            let tokens = response.tokens
            guard tokens.first?.text?.uppercased() == "SEARCH" else { return [] }
            return tokens.dropFirst().compactMap { $0.text.flatMap { UInt32($0) } }
        }
    }

    public func fetch(_ uids: [UInt32], _ part: FetchPart) async throws -> [FetchedMessage] {
        guard !uids.isEmpty else { return [] }
        let items = switch part {
        case .whole: isGmail ? "(UID X-GM-THRID BODY.PEEK[])" : "(UID BODY.PEEK[])"
        case .messageID: isGmail ? "(UID X-GM-THRID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])" : "(UID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])"
        case .threading: "(UID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID IN-REPLY-TO REFERENCES)])"
        }
        return try await command("UID FETCH", uids.map(String.init).joined(separator: ",") + " " + items).compactMap(Self.message)
    }

    // MARK: The wire

    /// Sends one command and reads until its tagged answer. The untagged responses that came
    /// before it are the result.
    private func command(_ verb: String, _ arguments: String) async throws -> [IMAPResponse] {
        guard Self.allowed.contains(verb) else { throw IMAPError.notReadOnly(verb) }
        // A fetch that asks for `BODY[]` or `RFC822` rather than `BODY.PEEK[]` marks mail as read.
        if verb == "UID FETCH", arguments.uppercased().contains("BODY[") || arguments.uppercased().contains("RFC822") {
            throw IMAPError.notReadOnly("\(verb) without PEEK")
        }
        counter += 1
        let tag = "M\(counter)"
        let line = arguments.isEmpty ? "\(tag) \(verb)\r\n" : "\(tag) \(verb) \(arguments)\r\n"
        try await transport.send(Data(line.utf8))

        var untagged: [IMAPResponse] = []
        while true {
            let response = try await nextResponse()
            if let status = response.status(tag: tag) {
                guard status.ok else { throw IMAPError.refused(command: verb, answer: status.rest) }
                return untagged
            }
            if response.text.uppercased().hasPrefix("* BYE"), verb != "LOGOUT" { throw IMAPError.closed }
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

    private func refreshCapabilities() async throws {
        for response in try await command("CAPABILITY", "") {
            let words = response.tokens.compactMap(\.text).map { $0.uppercased() }
            if words.first == "CAPABILITY" { capabilities = Set(words.dropFirst()) }
        }
    }

    static func message(from response: IMAPResponse) -> FetchedMessage? {
        let tokens = response.tokens
        guard tokens.count >= 3, tokens[1].text?.uppercased() == "FETCH", case .list(let items) = tokens[2] else { return nil }
        var uid: UInt32?
        var thread: String?
        var data: Data?
        for index in stride(from: 0, to: items.count - 1, by: 2) {
            guard let key = items[index].text?.uppercased() else { continue }
            let value = items[index + 1]
            if key == "UID" { uid = value.text.flatMap { UInt32($0) } }
            if key == "X-GM-THRID" { thread = value.text }
            if key.hasPrefix("BODY[") { data = value.data }
        }
        // A FETCH with no body in it is the server mentioning a flag change on its own. Not ours.
        guard let uid, let data else { return nil }
        return FetchedMessage(uid: uid, gmailThread: thread, data: data)
    }

    static func criterion(_ key: SearchKey) throws -> String {
        switch key {
        case .all:
            return "ALL"
        case .since(let date):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "d-MMM-yyyy"
            return "SINCE \(formatter.string(from: date))"
        case .gmailThread(let id):
            guard !id.isEmpty, id.allSatisfy(\.isASCII), id.allSatisfy(\.isNumber) else { throw IMAPError.unsafeArgument(id) }
            return "X-GM-THRID \(id)"
        case .messageID(let id):
            return "HEADER Message-ID \(try quoted("<\(id)>"))"
        case .replies(let id):
            let quoted = try quoted("<\(id)>")
            return "OR HEADER References \(quoted) HEADER In-Reply-To \(quoted)"
        case .subject(let words): return "SUBJECT \(try quoted(words))"
        case .from(let address): return "FROM \(try quoted(address))"
        case .to(let address): return "TO \(try quoted(address))"
        case .any(let keys):
            guard let first = keys.first else { throw IMAPError.unsafeArgument("an empty OR") }
            guard keys.count > 1 else { return try criterion(first) }
            return "OR (\(try criterion(first))) (\(try criterion(.any(Array(keys.dropFirst())))))"
        }
    }

    /// A quoted string. Anything that would need a literal instead — a line break, a byte
    /// outside ASCII — is refused rather than sent in a form the server might read otherwise.
    static func quoted(_ text: String) throws -> String {
        guard text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value < 0x7F }) else {
            throw IMAPError.unsafeArgument(text.count > 40 ? String(text.prefix(40)) + "…" : text)
        }
        return "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
