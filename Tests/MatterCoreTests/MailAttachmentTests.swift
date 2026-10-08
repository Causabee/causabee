import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("What came attached to a mail, as files of its matter")
@MainActor
struct MailAttachmentTests {
    private static func mail(_ parts: [String]) -> String {
        (["From: a@example.com", "Subject: x", "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=\"B\"", "",
          "--B", "Content-Type: text/plain; charset=utf-8", "", "Hello", ""] + parts + ["--B--", ""]).joined(separator: "\r\n")
    }

    private static func part(_ headers: [String], _ bytes: Data) -> String {
        (["--B"] + headers + ["Content-Transfer-Encoding: base64", "", bytes.base64EncodedString(options: .lineLength76Characters), ""]).joined(separator: "\r\n")
    }

    @Test("A logo set into the text and the mail's signature are left out; a file and a large picture stay")
    func decoration() {
        let source = Self.mail([
            Self.part(["Content-Type: application/pdf; name=\"Angebot.pdf\"", "Content-Disposition: attachment; filename=\"Angebot.pdf\""], Data(repeating: 1, count: 400)),
            Self.part(["Content-Type: image/png; name=\"logo.png\"", "Content-Disposition: inline; filename=\"logo.png\"", "Content-ID: <logo@x>"], Data(repeating: 2, count: 4_000)),
            Self.part(["Content-Type: application/pkcs7-signature; name=\"smime.p7s\"", "Content-Disposition: attachment; filename=\"smime.p7s\""], Data(repeating: 3, count: 900)),
            Self.part(["Content-Type: image/jpeg; name=\"IMG_1.jpg\"", "Content-Disposition: inline; filename=\"IMG_1.jpg\"", "Content-ID: <photo@x>"], Data(repeating: 4, count: 200_000)),
            // A small picture someone attached, with no place in the text, is a file.
            Self.part(["Content-Type: image/png; name=\"skizze.png\"", "Content-Disposition: attachment; filename=\"skizze.png\""], Data(repeating: 5, count: 4_000)),
        ])
        let email = EMLParser.parse(source: source, url: URL(fileURLWithPath: "/tmp/a.eml"))
        #expect(email.attachments.map(\.filename) == ["Angebot.pdf", "IMG_1.jpg", "skizze.png"])
    }

    @Test("The same file sent again is kept once; one of the same name that differs is kept as a second")
    func twins() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("folders-\(UUID())", isDirectory: true)
        MatterFolders.rootForTests = root
        defer { MatterFolders.rootForTests = nil; try? FileManager.default.removeItem(at: root) }
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "bad", name: "Bad")
        context.insert(matter)
        let day = ISO8601DateFormatter().date(from: "2026-09-14T10:00:00Z")!
        let later = ISO8601DateFormatter().date(from: "2026-09-16T10:00:00Z")!
        var mails: [URL] = []
        defer { for mail in mails { try? FileManager.default.removeItem(at: mail) } }
        func attached(_ id: String, _ date: Date, _ bytes: Data) throws -> Document {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("mail-\(UUID()).eml")
            try Data(Self.mail([Self.part(["Content-Type: application/pdf; name=\"Angebot.pdf\"", "Content-Disposition: attachment; filename=\"Angebot.pdf\""], bytes)]).utf8).write(to: file)
            mails.append(file)
            let document = Document(name: "Angebot.pdf", contentType: "application/pdf", byteCount: bytes.count,
                                    source: Source(kind: .mail, pointer: file.path, messageID: id, date: date))
            document.messageID = id
            context.insert(document); document.matter = matter
            return document
        }
        let first = try attached("a@x", day, Data(repeating: 1, count: 400))
        // Sent again two days on, to the byte the same.
        let again = try attached("b@x", later, Data(repeating: 1, count: 400))
        // The same day and name as the first, from another mail, one byte different.
        let changed = try attached("c@x", day, Data(repeating: 1, count: 399) + Data([2]))

        let result = await MatterFolders.save([matter], account: nil, password: nil)
        let folder = try #require(MatterFolders.folder(for: matter))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(names == ["2026-09-14 Angebot 2.pdf", "2026-09-14 Angebot.pdf"])
        #expect(result.saved == 2 && result.failed.isEmpty)
        #expect(!first.isHidden && again.isHidden && !changed.isHidden)
        #expect(MatterFolders.kept(changed)?.lastPathComponent == "2026-09-14 Angebot 2.pdf")
        // Saved again, nothing is fetched or written twice.
        let second = await MatterFolders.save([matter], account: nil, password: nil)
        #expect(second.saved == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).count == 2)
    }
}
