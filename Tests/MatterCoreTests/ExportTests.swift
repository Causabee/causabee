import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("A matter written out as RTF")
@MainActor
struct ExportTests {
    @Test("Every part with something in it is there, an empty one is not, and what RTF cannot hold is escaped")
    func export() throws {
        let container = try MatterSchema.container(at: nil)
        let context = container.mainContext
        let matter = try Matter.make(named: "Müllers {Haus}: Kauf/Vertrag", in: context)
        let todo = Todo(text: "Notar “anrufen”", owner: .me, due: "2026-10-25", source: Source(kind: .conversation, pointer: "you", date: Date()), origin: "you#1")
        todo.dueTime = "15:10"
        context.insert(todo)
        todo.matter = matter
        let note = MatterNote(text: "Zwei Zeilen\nund ein \\ Strich")
        context.insert(note)
        note.matter = matter

        let titles = MatterExport.sections(of: matter).map(\.title)
        #expect(titles == ["Tasks", "Notes"])
        let task = try #require(MatterExport.sections(of: matter).first?.lines.first)
        #expect(task.text == "Notar “anrufen”")
        #expect(task.detail?.contains("at 15:10") == true)

        let text = try #require(String(data: MatterExport.rtf(for: matter), encoding: .utf8))
        #expect(text.hasPrefix(#"{\rtf1"#) && text.hasSuffix("}"))
        let ascii = text.unicodeScalars.allSatisfy { $0.isASCII }
        #expect(ascii)
        #expect(text.contains(#"M\u252?llers \{Haus\}: Kauf/Vertrag"#))
        #expect(text.contains(#"Zwei Zeilen\line und ein \\ Strich"#))
        #expect(MatterExport.fileName(for: matter) == "Müllers {Haus}  Kauf Vertrag.rtf")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("export-test-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try MatterExport.write(matter, into: folder)
        #expect(file.deletingLastPathComponent().path == folder.path)
        #expect(file.lastPathComponent == MatterExport.fileName(for: matter))
        let written = try Data(contentsOf: file)
        #expect(String(data: written, encoding: .utf8)?.contains(#"\{Haus\}"#) == true)
    }
}
