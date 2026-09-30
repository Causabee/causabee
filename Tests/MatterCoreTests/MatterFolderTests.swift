import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("A folder per matter")
@MainActor
struct MatterFolderTests {
    @Test("Named after the matter, renamed with it; files dated; hidden files, logos and mail files left out")
    func folder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("folders-\(UUID())", isDirectory: true)
        MatterFolders.rootForTests = root
        defer { MatterFolders.rootForTests = nil; try? FileManager.default.removeItem(at: root) }
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "reise", name: "Reise: Lyon/Paris")
        context.insert(matter)
        let day = ISO8601DateFormatter().date(from: "2026-09-14T10:00:00Z")!
        let mail = Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "a@example", date: day)
        let pdf = Document(name: "Rechnung.pdf", contentType: "application/pdf", byteCount: 90_000, source: mail)
        let logo = Document(name: "logo.png", contentType: "image/png", byteCount: 4_000, source: mail)
        let old = Document(name: "Alt.pdf", contentType: "application/pdf", byteCount: 90_000, source: mail)
        old.isHidden = true
        for document in [pdf, logo, old] { context.insert(document); document.matter = matter }
        let shot = FileManager.default.temporaryDirectory.appendingPathComponent("chat-\(UUID()).png")
        try Data("png".utf8).write(to: shot)
        defer { try? FileManager.default.removeItem(at: shot) }
        let eml = FileManager.default.temporaryDirectory.appendingPathComponent("mail-\(UUID()).eml")
        try Data("mail".utf8).write(to: eml)
        defer { try? FileManager.default.removeItem(at: eml) }
        for (kind, file) in [(Source.Kind.screenshot, shot), (.mail, eml)] {
            let entry = Entry(title: "x", from: "x", date: day, source: Source(kind: kind, pointer: file.path, messageID: UUID().uuidString, date: day))
            context.insert(entry); entry.matter = matter
        }

        let folder = try #require(MatterFolders.folder(for: matter))
        #expect(folder.lastPathComponent == "Reise- Lyon-Paris")
        #expect(MatterFolders.place(for: pdf, in: folder).lastPathComponent == "2026-09-14 Rechnung.pdf")
        #expect(MatterFolders.wanted(matter).map(\.name) == ["Rechnung.pdf"])
        #expect(MatterFolders.dropped(matter).map(\.file) == [shot])

        matter.rename(to: "Reise nach Lyon")
        let moved = try #require(MatterFolders.folder(for: matter))
        #expect(moved.lastPathComponent == "Reise nach Lyon")
        #expect(!FileManager.default.fileExists(atPath: folder.path) && FileManager.default.fileExists(atPath: moved.path))
    }
}
