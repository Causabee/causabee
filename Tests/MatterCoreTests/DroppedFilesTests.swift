import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("A file taken in is a file of its matter")
@MainActor
struct DroppedFilesTests {
    /// A scanned letter, copied in beside the store as the app does with a file that has no home.
    func scan() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(ScreenshotDoor.attachmentsFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("1A2B3C4D-Brief der Versicherung.pdf")
        try Data("%PDF-1.4 a letter".utf8).write(to: file)
        return file
    }

    func letter(at file: URL) throws -> Judgement {
        let json: [String: Any] = [
            "email_id": "document:0a1b2c3d", "source": file.path, "date": "2026-09-30T10:00:00Z",
            "subject": "Brief der Versicherung", "from": "", "is_bulk": false, "matter": "dach", "matter_confidence": 0.9,
            "matter_reason": "", "decided_by": "claude", "todos": [], "deadlines": [], "appointments": [], "done": [], "parties": [],
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Judgement.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("The letter shows under the matter's files once, by the name it had, read already")
    func takenIn() throws {
        let file = try scan()
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply([try letter(at: file)], to: context)
        _ = try MatterImport.apply([try letter(at: file)], to: context)
        let matter = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        let documents = matter.documents ?? []
        #expect(documents.count == 1)
        let document = try #require(documents.first)
        #expect(document.name == "Brief der Versicherung.pdf")
        #expect(document.isOwnFile)
        #expect(document.contentType == "application/pdf")
        #expect(document.source.fileURL == file)
        #expect(document.readAt != nil)
    }

    @Test("Deleted, the letter is gone with what only it brought; what the owner added stays")
    func forgotten() throws {
        let file = try scan()
        let context = ModelContext(try MatterSchema.container(at: nil))
        var judgement = try letter(at: file)
        judgement.todos = [.init(text: "Schadensmeldung ausfüllen", owner: .me, due: "2026-10-10", sourceQuote: "Bitte füllen Sie aus")]
        _ = try MatterImport.apply([judgement], to: context)
        let matter = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        matter.addDetail(label: "Schadennummer", value: "S-4711", in: context)
        try context.save()
        let document = try #require(matter.documents?.first)
        #expect(matter.brought(by: document).todos.map(\.text) == ["Schadensmeldung ausfüllen"])

        #expect(matter.forget(document, besides: nil, in: context))
        try context.save()
        #expect((matter.documents ?? []).isEmpty)
        #expect((matter.entries ?? []).isEmpty)
        #expect((matter.todos ?? []).isEmpty)
        #expect(matter.sortedDetails.map(\.value) == ["S-4711"])
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("One taken in before files were kept is added when Causabee starts, and only once")
    func takenInBefore() throws {
        let file = try scan()
        let context = ModelContext(try MatterSchema.container(at: nil))
        _ = try MatterImport.apply([try letter(at: file)], to: context)
        let matter = try #require(try context.fetch(FetchDescriptor<Matter>()).first)
        for document in matter.documents ?? [] { context.delete(document) }
        try context.save()
        #expect((matter.documents ?? []).isEmpty)

        #expect(try MatterImport.addDroppedFiles(to: context) == 1)
        #expect(try MatterImport.addDroppedFiles(to: context) == 0)
        #expect(matter.documents?.map(\.name) == ["Brief der Versicherung.pdf"])
    }

    @Test("Only the prefix of a copy is taken off, not a name's own date")
    func names() {
        #expect(Document.ownName(of: URL(fileURLWithPath: "/x/Anhänge/1A2B3C4D-Brief.pdf")) == "Brief.pdf")
        #expect(Document.ownName(of: URL(fileURLWithPath: "/x/Scans/20260930-Brief.pdf")) == "20260930-Brief.pdf")
        #expect(Document.ownName(of: URL(fileURLWithPath: "/x/Anhänge/Brief.pdf")) == "Brief.pdf")
    }
}
