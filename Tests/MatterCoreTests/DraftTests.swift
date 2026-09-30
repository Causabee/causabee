import Foundation
import Testing
@testable import MatterCore

/// A pretend Gmail that answers the draft connection line by line, and keeps what it was sent.
final class DraftServer: IMAPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var outgoing: [Data] = [Data("* OK Gimap ready\r\n".utf8)]
    private(set) var lines: [String] = []
    private(set) var message: Data?
    private var awaitingLiteral: (tag: String, count: Int)?

    func send(_ data: Data) async throws {
        lock.withLock {
            if let (tag, _) = awaitingLiteral {
                message = data.dropLast(2)
                awaitingLiteral = nil
                outgoing.append(Data("\(tag) OK [APPENDUID 1 42] APPEND completed\r\n".utf8))
                return
            }
            let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
            lines.append(line)
            let tag = String(line.prefix { $0 != " " })
            let command = line.dropFirst(tag.count + 1)
            if command.hasPrefix("LIST") {
                outgoing.append(Data("* LIST (\\HasNoChildren) \"/\" \"INBOX\"\r\n* LIST (\\HasNoChildren \\Drafts) \"/\" \"[Gmail]/Entw&APw-rfe\"\r\n* LIST (\\HasNoChildren \\Sent) \"/\" \"[Gmail]/Gesendet\"\r\n\(tag) OK LIST done\r\n".utf8))
            } else if command.hasPrefix("APPEND"), let match = line.firstMatch(of: /\{(\d+)\}$/), let count = Int(match.output.1) {
                awaitingLiteral = (tag, count)
                outgoing.append(Data("+ go ahead\r\n".utf8))
            } else {
                outgoing.append(Data("\(tag) OK done\r\n".utf8))
            }
        }
    }

    func receive() async throws -> Data { lock.withLock { outgoing.isEmpty ? Data() : outgoing.removeFirst() } }
    func close() async {}
}

@Suite("A draft into Gmail: the one write, and only that")
struct DraftTests {
    @Test("The draft goes into the folder marked Drafts, flagged as one, and nothing else is sent")
    func put() async throws {
        let server = DraftServer()
        let door = DraftDoor(transport: server)
        try await door.start(user: "jan@example.com", password: "app-password")
        let draft = DraftMessage(from: "jan@example.com", to: (name: "Petra Lindner", address: "petra@example.org"),
                                 subject: "Liste für den Sperrmüll", body: "Hallo Petra,\nhier die Liste.\n\nViele Grüße\nJan",
                                 replyingTo: "liste-1@example.org")
        let folder = try await door.put(draft.data)
        await door.logout()

        #expect(folder == "[Gmail]/Entwürfe")
        let verbs = server.lines.map { $0.split(separator: " ").dropFirst().first.map(String.init) ?? "" }
        #expect(verbs == ["LOGIN", "LIST", "APPEND", "LOGOUT"])
        #expect(server.lines[2].contains("\"[Gmail]/Entw&APw-rfe\" (\\Draft) {"))
        let sent = String(decoding: try #require(server.message), as: UTF8.self)
        #expect(sent.contains("To: Petra Lindner <petra@example.org>\r\n"))
        #expect(sent.contains("Subject: =?UTF-8?B?"))
        #expect(sent.contains("In-Reply-To: <liste-1@example.org>\r\nReferences: <liste-1@example.org>\r\n"))
        let body = try #require(sent.components(separatedBy: "\r\n\r\n").last)
        let decoded = String(decoding: try #require(Data(base64Encoded: body, options: .ignoreUnknownCharacters)), as: UTF8.self)
        #expect(decoded == "Hallo Petra,\r\nhier die Liste.\r\n\r\nViele Grüße\r\nJan")
    }

    @Test("The reading client still cannot send APPEND; the draft connection cannot send anything but its six")
    func lists() {
        #expect(!IMAPClient.allowed.contains("APPEND"))
        #expect(DraftDoor.allowed == ["CAPABILITY", "LOGIN", "AUTHENTICATE", "LIST", "APPEND", "LOGOUT"])
        #expect(!DraftDoor.allowed.contains { ["STORE", "COPY", "MOVE", "EXPUNGE", "SELECT", "UID STORE", "DELETE"].contains($0) })
    }

    @Test("An account with no Drafts folder gets no draft anywhere else")
    func noDrafts() async throws {
        final class Bare: IMAPTransport, @unchecked Sendable {
            let lock = NSLock()
            var outgoing = [Data("* OK ready\r\n".utf8)]
            var appended = false
            func send(_ data: Data) async throws {
                let line = String(decoding: data, as: UTF8.self)
                let tag = String(line.prefix { $0 != " " })
                lock.withLock {
                    if line.contains(" APPEND ") { appended = true }
                    outgoing.append(Data((line.contains(" LIST ") ? "* LIST () \"/\" \"INBOX\"\r\n" : "") .utf8) + Data("\(tag) OK\r\n".utf8))
                }
            }
            func receive() async throws -> Data { lock.withLock { outgoing.isEmpty ? Data() : outgoing.removeFirst() } }
            func close() async {}
        }
        let server = Bare()
        let door = DraftDoor(transport: server)
        try await door.start(user: "jan@example.com", password: "x")
        await #expect(throws: DraftDoor.Failure.self) { try await door.put(Data("x".utf8)) }
        #expect(!server.appended)
    }
}
