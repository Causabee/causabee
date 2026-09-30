import Foundation
import Testing
@testable import MatterCore

/// A pretend Gmail with a Matterbee label, keeping what the scan connection sent.
private final class LabelServer: IMAPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var outgoing: [Data] = [Data("* OK Gimap ready\r\n".utf8)]
    private(set) var lines: [String] = []
    private(set) var message: Data?
    private var awaitingLiteral: String?
    let folders: String

    init(folders: String = "* LIST (\\HasNoChildren) \"/\" \"INBOX\"\r\n* LIST (\\HasNoChildren) \"/\" \"Matterbee\"\r\n* LIST (\\HasNoChildren \\Drafts) \"/\" \"[Gmail]/Drafts\"\r\n") {
        self.folders = folders
    }

    func send(_ data: Data) async throws {
        lock.withLock {
            if let tag = awaitingLiteral {
                message = data.dropLast(2)
                awaitingLiteral = nil
                outgoing.append(Data("\(tag) OK [APPENDUID 1 7] APPEND completed\r\n".utf8))
                return
            }
            let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
            lines.append(line)
            let tag = String(line.prefix { $0 != " " })
            let command = line.dropFirst(tag.count + 1)
            if command.hasPrefix("LIST") {
                outgoing.append(Data((folders + "\(tag) OK LIST done\r\n").utf8))
            } else if command.hasPrefix("APPEND") {
                awaitingLiteral = tag
                outgoing.append(Data("+ go ahead\r\n".utf8))
            } else {
                outgoing.append(Data("\(tag) OK done\r\n".utf8))
            }
        }
    }

    func receive() async throws -> Data { lock.withLock { outgoing.isEmpty ? Data() : outgoing.removeFirst() } }
    func close() async {}
}

@Suite("A scanned paper document into the Matterbee label: kept in the mail, like an attachment")
struct ScanTests {
    let scan = Data("%PDF-1.7 a letter from the tax office".utf8)

    @Test("The scan goes into the label and no other folder, marked read, and nothing else is sent")
    func intoLabel() async throws {
        let server = LabelServer()
        let door = DraftDoor(transport: server)
        try await door.start(user: "jan@example.com", password: "app-password")
        let letter = ScanMessage(owner: "jan@example.com", title: "Steuerbescheid 2025", matter: "Steuer 2025",
                                   file: (name: "Steuerbescheid.pdf", contentType: "application/pdf", data: scan))
        let folder = try await door.put(letter.data, intoLabel: "matterbee")
        await door.logout()

        #expect(folder == "Matterbee")
        let verbs = server.lines.map { $0.split(separator: " ").dropFirst().first.map(String.init) ?? "" }
        #expect(verbs == ["LOGIN", "LIST", "APPEND", "LOGOUT"])
        #expect(server.lines[2].contains("\"Matterbee\" (\\Seen) {"))
        #expect(try #require(server.message) == letter.data)
    }

    @Test("A mailbox without the label gets the scan nowhere else")
    func noLabel() async throws {
        let server = LabelServer(folders: "* LIST (\\HasNoChildren) \"/\" \"INBOX\"\r\n")
        let door = DraftDoor(transport: server)
        try await door.start(user: "jan@example.com", password: "x")
        await #expect(throws: DraftDoor.Failure.self) { try await door.put(Data("x".utf8), intoLabel: "Matterbee") }
        #expect(!server.lines.contains { $0.contains(" APPEND ") })
    }

    @Test("The scan reads back as a mail from the owner with the scan attached, the matter named in the subject")
    func message() throws {
        let letter = ScanMessage(owner: "jan@example.com", title: "Brief der Hausverwaltung", matter: "Wohnung Lindenstraße",
                                   file: (name: "Brief März.pdf", contentType: "application/pdf", data: scan),
                                   date: Date(timeIntervalSince1970: 1_790_000_000))
        let email = EMLParser.parse(data: letter.data, url: URL(fileURLWithPath: "/letter.eml"))
        #expect(email.id == letter.messageID)
        #expect(email.subject == "Document: Brief der Hausverwaltung — for “Wohnung Lindenstraße”")
        #expect(email.from.contains("jan@example.com"))
        #expect(email.attachments.map(\.filename) == ["Brief März.pdf"])
        #expect(EMLParser.attachment(named: "Brief März.pdf", in: letter.data) == scan)
    }
}
