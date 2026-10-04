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

    @Test("A file brought in on one device is put into the matter's folder and found there by the other")
    func shared() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("folders-\(UUID())", isDirectory: true)
        MatterFolders.rootForTests = root
        defer { MatterFolders.rootForTests = nil; try? FileManager.default.removeItem(at: root) }
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "reha", name: "Reha Mama")
        context.insert(matter)
        let day = ISO8601DateFormatter().date(from: "2026-10-04T10:00:00Z")!
        // As the other device sees it: a path that is not on this one.
        let source = Source(kind: .document, pointer: "/var/mobile/Containers/Data/Application/X/Documents/Brief.png", messageID: "screenshot:ab", date: day)
        let letter = Document(name: "Brief.png", contentType: "image/png", byteCount: 5, source: source)
        context.insert(letter)
        letter.matter = matter
        #expect(MatterFolders.kept(letter) == nil)

        let photo = FileManager.default.temporaryDirectory.appendingPathComponent("photo-\(UUID()).png")
        try Data("photo".utf8).write(to: photo)
        defer { try? FileManager.default.removeItem(at: photo) }
        let target = try #require(MatterFolders.keep(photo, as: letter))
        #expect(target.path.hasSuffix("Reha Mama/2026-10-04 Brief.png"))
        #expect(MatterFolders.kept(letter) == target)
        let opened = try await MatterFolders.fetched(target)
        #expect(try Data(contentsOf: opened) == Data("photo".utf8))
    }

    @Test("The earlier folder's matters come along into Causabee's own; nothing there is overwritten, and the empty old folder goes")
    func broughtAlong() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("move-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let old = base.appendingPathComponent("old"), new = base.appendingPathComponent("new")
        for folder in ["old/Reha Mama", "old/Steuer", "new/Reha Mama"] {
            try FileManager.default.createDirectory(at: base.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try Data("mac".utf8).write(to: old.appendingPathComponent("Reha Mama/Brief.pdf"))
        try Data("old".utf8).write(to: old.appendingPathComponent("Reha Mama/Foto.png"))
        try Data("phone".utf8).write(to: new.appendingPathComponent("Reha Mama/Foto.png"))
        try Data("tax".utf8).write(to: old.appendingPathComponent("Steuer/Bescheid.pdf"))

        MatterFolders.bringAlong(from: old, to: new)
        #expect(try Data(contentsOf: new.appendingPathComponent("Reha Mama/Brief.pdf")) == Data("mac".utf8))
        #expect(try Data(contentsOf: new.appendingPathComponent("Reha Mama/Foto.png")) == Data("phone".utf8))
        #expect(try Data(contentsOf: new.appendingPathComponent("Steuer/Bescheid.pdf")) == Data("tax".utf8))
        // The one file that could not move without overwriting is still where it was.
        #expect(try Data(contentsOf: old.appendingPathComponent("Reha Mama/Foto.png")) == Data("old".utf8))
        #expect(!FileManager.default.fileExists(atPath: old.appendingPathComponent("Steuer").path))
    }
}
