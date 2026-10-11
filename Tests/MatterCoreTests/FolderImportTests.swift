import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("A folder brought into a matter")
struct FolderImportTests {
    /// A folder as one lies in iCloud Drive: files, a folder in a folder, and what is not a file to keep.
    func folder() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Mama", isDirectory: true)
        let files = FileManager.default
        try files.createDirectory(at: root.appendingPathComponent("Rechnungen/2025", isDirectory: true), withIntermediateDirectories: true)
        try Data("a".utf8).write(to: root.appendingPathComponent("Brief.pdf"))
        try Data("bb".utf8).write(to: root.appendingPathComponent("Rechnungen/Rechnung.pdf"))
        try Data("ccc".utf8).write(to: root.appendingPathComponent("Rechnungen/2025/Rechnung.pdf"))
        try Data("x".utf8).write(to: root.appendingPathComponent(".DS_Store"))
        try Data("x".utf8).write(to: root.appendingPathComponent("Rechnungen/.Scan.pdf.icloud"))
        return root
    }

    @Test("Every file in it and under it is taken, the folders are not, nor what is hidden or not brought down yet")
    func everyFileHoweverDeep() throws {
        let root = try folder()
        let names = FolderImport.files(in: [root]).map { $0.path.components(separatedBy: "/Mama/").last ?? "" }
        #expect(names == ["Brief.pdf", "Rechnungen/2025/Rechnung.pdf", "Rechnungen/Rechnung.pdf"])
    }

    @Test("A file picked beside a folder is itself")
    func aFileIsItself() throws {
        let root = try folder()
        let file = root.appendingPathComponent("Brief.pdf")
        #expect(FolderImport.files(in: [file]).map(\.lastPathComponent) == ["Brief.pdf"])
    }

    @Test("Two files of one name from two folders are both kept, the second as “… 2”")
    func twoOfOneName() {
        var taken: [String: Set<Int>] = [:]
        #expect(FolderImport.name(for: "Rechnung.pdf", size: 3, taken: &taken) == "Rechnung.pdf")
        #expect(FolderImport.name(for: "Rechnung.pdf", size: 2, taken: &taken) == "Rechnung 2.pdf")
        #expect(FolderImport.name(for: "Notiz", size: 5, taken: &taken) == "Notiz")
        #expect(FolderImport.name(for: "Notiz", size: 6, taken: &taken) == "Notiz 2")
    }

    @Test("The folder brought a second time adds nothing: the same name with the same size is there already")
    func aSecondTimeAddsNothing() {
        var taken: [String: Set<Int>] = [:]
        #expect(FolderImport.name(for: "Rechnung.pdf", size: 3, taken: &taken) == "Rechnung.pdf")
        #expect(FolderImport.name(for: "Rechnung.pdf", size: 2, taken: &taken) == "Rechnung 2.pdf")
        #expect(FolderImport.name(for: "Rechnung.pdf", size: 3, taken: &taken) == nil)
        #expect(FolderImport.name(for: "Rechnung.pdf", size: 2, taken: &taken) == nil)
        #expect(FolderImport.name(for: "rechnung.PDF", size: 3, taken: &taken) == nil)
        // A third of that name, changed since: kept beside the two.
        #expect(FolderImport.name(for: "Rechnung.pdf", size: 9, taken: &taken) == "Rechnung 3.pdf")
    }

    @Test("What the matter has of its owner's files counts as there; a mail's attachment of the same name does not")
    func whatTheMatterHas() {
        let own = Document(name: "Brief.pdf", contentType: "application/pdf", byteCount: 1,
                           source: Source(kind: .document, pointer: "/tmp/Brief.pdf", messageID: "file-1", date: Date()))
        let attached = Document(name: "Anhang.pdf", contentType: "application/pdf", byteCount: 7,
                                source: Source(kind: .mail, pointer: "imap://x;UID=1", messageID: "<a@b>", date: Date()))
        var taken = FolderImport.taken(by: [own, attached])
        #expect(FolderImport.name(for: "Brief.pdf", size: 1, taken: &taken) == nil)
        #expect(FolderImport.name(for: "Anhang.pdf", size: 7, taken: &taken) == "Anhang.pdf")
    }

    @Test("One file added says nothing, as before; a folder says what came and what was there")
    func whatIsSaid() {
        #expect(FolderImport.said(added: 1, already: 0, failed: 0) == nil)
        #expect(FolderImport.said(added: 12, already: 0, failed: 0) == "12 files added")
        #expect(FolderImport.said(added: 1, already: 3, failed: 0) == "1 file added · 3 already here")
        #expect(FolderImport.said(added: 0, already: 4, failed: 1) == "Nothing new · 4 already here · 1 could not be read")
    }

    @Test("A folder brought into a matter: three files of it, the folders gone; brought again, nothing more")
    @MainActor
    func intoTheMatter() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "mama")
        context.insert(matter)
        let root = try folder()
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: kept, withIntermediateDirectories: true)
        let copy: (URL, String) -> URL? = { file, name in
            let target = kept.appendingPathComponent(name)
            return (try? FileManager.default.copyItem(at: file, to: target)) != nil ? target : nil
        }
        let first = FolderImport.add([root], to: matter, context: context, copy: copy)
        #expect(first == FolderImport.Result(added: 3, already: 0, failed: 0))
        let documents = (matter.documents ?? []).sorted { $0.name < $1.name }
        #expect(documents.map(\.name) == ["Brief.pdf", "Rechnung 2.pdf", "Rechnung.pdf"])
        #expect(documents.allSatisfy { $0.isOwnFile && $0.source.fileURL.map { FileManager.default.fileExists(atPath: $0.path) } == true })
        #expect(documents.map(\.byteCount) == [1, 2, 3])
        let again = FolderImport.add([root], to: matter, context: context, copy: copy)
        #expect(again == FolderImport.Result(added: 0, already: 3, failed: 0))
        #expect(matter.documents?.count == 3)
        // One more put into the folder since: only that one comes.
        try Data("dddd".utf8).write(to: root.appendingPathComponent("Neu.pdf"))
        #expect(FolderImport.add([root], to: matter, context: context, copy: copy) == FolderImport.Result(added: 1, already: 3, failed: 0))
    }
}
