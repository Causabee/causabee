import Foundation
import Testing
@testable import MatterCore

/// A mail server that answers from a script, a few bytes at a time — the way a real one
/// splits a long mail across many reads.
final class ScriptedServer: IMAPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var outgoing: [Data] = []
    private(set) var sent: [String] = []
    private let answer: @Sendable (_ tag: String, _ command: String) -> String
    let chunk: Int

    init(chunk: Int = 7, answer: @escaping @Sendable (_ tag: String, _ command: String) -> String) {
        self.answer = answer
        self.chunk = chunk
        queue("* OK [CAPABILITY IMAP4rev1] ready\r\n")
    }

    private func queue(_ text: String) {
        let bytes = Data(text.utf8)
        for start in stride(from: 0, to: bytes.count, by: chunk) {
            outgoing.append(bytes[start..<min(start + chunk, bytes.count)])
        }
    }

    func send(_ data: Data) async throws {
        let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
        let tag = String(line.prefix { $0 != " " })
        let command = String(line.dropFirst(tag.count + 1))
        lock.withLock {
            sent.append(command)
            queue(answer(tag, command))
        }
    }

    func receive() async throws -> Data {
        lock.withLock { outgoing.isEmpty ? Data() : outgoing.removeFirst() }
    }

    func close() async {}
}

@Suite("Reading mail over IMAP, and only reading it")
struct IMAPTests {
    static let mail = """
    Message-ID: <a1@berger-hv.example>\r
    From: Annegret Berger <post@berger-hv.example>\r
    Subject: Sonderumlage\r
    \r
    Bitte bis 30.11. zahlen.\r
    M7 OK this line is inside the mail, not the end of the command\r

    """

    /// A Gmail-shaped server: labels as folders, All Mail marked `\\All`, threads by X-GM-THRID.
    static func gmail() -> ScriptedServer {
        ScriptedServer { tag, command in
            let verb = command.split(separator: " ").prefix(2).joined(separator: " ").uppercased()
            switch verb {
            case "CAPABILITY": return "* CAPABILITY IMAP4rev1 X-GM-EXT-1 UIDPLUS\r\n\(tag) OK done\r\n"
            case let v where v.hasPrefix("LOGIN"):
                return command.contains("\"right\"") ? "\(tag) OK logged in\r\n"
                    : "\(tag) NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)\r\n"
            case let v where v.hasPrefix("LIST"):
                return """
                * LIST (\\HasNoChildren) "/" "INBOX"\r
                * LIST (\\HasNoChildren) "/" "Matterbee"\r
                * LIST (\\HasNoChildren) "/" "Vertr&AOQ-ge"\r
                * LIST (\\All \\HasNoChildren) "/" "[Gmail]/Alle Nachrichten"\r
                * LIST (\\HasChildren \\Noselect) "/" "[Gmail]"\r
                \(tag) OK done\r

                """
            case let v where v.hasPrefix("EXAMINE"):
                return "* 3 EXISTS\r\n* OK [UIDVALIDITY 3857529045] UIDs valid\r\n\(tag) OK [READ-ONLY] examined\r\n"
            case "UID SEARCH": return "* SEARCH 4 9\r\n\(tag) OK done\r\n"
            case "UID FETCH":
                let body = Data(mail.utf8)
                return "* 1 FETCH (X-GM-THRID 1812345678901234567 UID 4 BODY[] {\(body.count)}\r\n\(mail))\r\n" +
                       "* 2 FETCH (UID 9 FLAGS (\\Seen))\r\n\(tag) OK done\r\n"
            case "LOGOUT": return "* BYE bye\r\n\(tag) OK done\r\n"
            default: return "\(tag) BAD unknown\r\n"
            }
        }
    }

    static func loggedIn(_ server: ScriptedServer, password: String = "right") async throws -> IMAPClient {
        let client = IMAPClient(transport: server)
        try await client.start()
        try await client.login(user: "owner@gmail.com", password: password)
        return client
    }

    @Test("A whole session: folders decoded, the folder opened read-only, the mail left unread")
    func session() async throws {
        let server = Self.gmail()
        let client = try await Self.loggedIn(server)
        #expect(await client.isGmail)

        let folders = try await client.folders()
        #expect(folders.map(\.name).contains("Verträge"))
        #expect(folders.first { $0.attributes.contains("\\all") }?.name == "[Gmail]/Alle Nachrichten")

        let opened = try await client.examine("Matterbee")
        #expect(opened.uidValidity == 3857529045)
        #expect(opened.exists == 3)

        #expect(try await client.search([.all]) == [4, 9])
        let messages = try await client.fetch([4, 9], .whole)
        // The flag change the server mentioned on its own is not a mail.
        #expect(messages.count == 1)
        #expect(messages[0].uid == 4)
        #expect(messages[0].gmailThread == "1812345678901234567")
        // The line inside the literal that looks like the end of the command is read as mail.
        #expect(String(decoding: messages[0].data, as: UTF8.self) == Self.mail)

        await client.logout()
        let verbs = server.sent.map { $0.split(separator: " ").prefix(2).joined(separator: " ") }
        #expect(server.sent.contains("EXAMINE \"Matterbee\""))
        #expect(!server.sent.contains { $0.uppercased().hasPrefix("SELECT") })
        #expect(server.sent.contains("UID FETCH 4,9 (UID X-GM-THRID BODY.PEEK[])"))
        for verb in verbs {
            #expect(IMAPClient.allowed.contains(verb) || IMAPClient.allowed.contains(String(verb.split(separator: " ")[0])))
        }
    }

    @Test("Nothing that changes a mailbox is on the list of commands it can send")
    func readOnly() {
        for verb in ["SELECT", "STORE", "UID STORE", "COPY", "UID COPY", "MOVE", "UID MOVE", "EXPUNGE",
                     "UID EXPUNGE", "APPEND", "DELETE", "RENAME", "CREATE", "SUBSCRIBE"] {
            #expect(!IMAPClient.allowed.contains(verb), "\(verb)")
        }
    }

    @Test("A wrong password is refused, says what to use instead, and is not repeated")
    func wrongPassword() async throws {
        await #expect {
            _ = try await Self.loggedIn(Self.gmail(), password: "hunter2")
        } throws: { error in
            let text = "\(error)"
            return (error as? IMAPError) == .refused(command: "LOGIN", answer: "NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)")
                && text.contains("app password") && !text.contains("hunter2")
        }
    }

    @Test("Many threads in one search: nested ORs, one round trip")
    func anyOf() throws {
        #expect(try IMAPClient.criterion(.any([.gmailThread("1")])) == "X-GM-THRID 1")
        #expect(try IMAPClient.criterion(.any([.gmailThread("1"), .gmailThread("2"), .gmailThread("3")]))
                == "OR (X-GM-THRID 1) (OR (X-GM-THRID 2) (X-GM-THRID 3))")
        #expect(throws: IMAPError.self) { try IMAPClient.criterion(.any([])) }
        #expect(throws: IMAPError.self) { try IMAPClient.criterion(.any([.gmailThread("1 OR ALL")])) }
    }

    @Test("A line break cannot be smuggled into a command")
    func noInjection() throws {
        #expect(throws: IMAPError.self) { try IMAPClient.quoted("Matterbee\r\nM9 UID STORE 1:* +FLAGS (\\Deleted)") }
        #expect(throws: IMAPError.self) { try IMAPClient.criterion(.gmailThread("1 OR ALL")) }
        #expect(try IMAPClient.quoted("a\"b\\c") == "\"a\\\"b\\\\c\"")
    }

    @Test("Replies are searched by the headers made for it")
    func replyCriterion() throws {
        #expect(try IMAPClient.criterion(.replies(to: "a1@berger-hv.example"))
                == "OR HEADER References \"<a1@berger-hv.example>\" HEADER In-Reply-To \"<a1@berger-hv.example>\"")
        #expect(try IMAPClient.criterion(.gmailThread("1812345678901234567")) == "X-GM-THRID 1812345678901234567")
    }

    @Test("Folder names in IMAP's own UTF-7, both ways", arguments: [
        ("Verträge", "Vertr&AOQ-ge"),
        ("Tom & Jerry", "Tom &- Jerry"),
        ("[Gmail]/Alle Nachrichten", "[Gmail]/Alle Nachrichten"),
        ("~peter/mail/台北/日本語", "~peter/mail/&U,BTFw-/&ZeVnLIqe-"),
    ])
    func mailboxNames(name: String, wire: String) {
        #expect(MailboxName.encode(name) == wire)
        #expect(MailboxName.decode(wire) == name)
    }

    @Test("A response is not read before all of it has arrived")
    func partialResponse() {
        var reader = IMAPReader()
        reader.append(Data("* 1 FETCH (UID 4 BODY[] {5}\r\nab".utf8))
        #expect(reader.next() == nil)
        reader.append(Data("cde)\r\nM1 OK".utf8))
        #expect(reader.next() == IMAPResponse(text: "* 1 FETCH (UID 4 BODY[] \u{0})", literals: [Data("abcde".utf8)]))
        #expect(reader.next() == nil)
        reader.append(Data(" done\r\n".utf8))
        #expect(reader.next()?.text == "M1 OK done")
    }
}

@Test func onlyKnownDomainsNameTheirServer() {
    #expect(MailAccount(user: "someone@gmail.com")?.host == "imap.gmail.com")
    #expect(MailAccount(user: "someone@icloud.com")?.host == "imap.mail.me.com")
    // Any other domain has no account until its server is named: no password to a guessed server.
    #expect(MailAccount(user: "someone@example.org") == nil)
    #expect(MailAccount(user: "someone@example.org", host: "imap.example.org").host == "imap.example.org")
}
