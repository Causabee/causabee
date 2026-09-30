import Foundation
import SwiftData
import Testing
@testable import MatterCore

@Suite("Finding a matter on the Mac")
@MainActor
struct MatterSearchTests {
    @Test("By name in any spelling first, then by a task's words, then by a mail's")
    func find() throws {
        let context = ModelContext(try MatterSchema.container(at: nil))
        let sperr = Matter(key: "sperrmuell", name: "Sperrmüll"), roof = Matter(key: "dach", name: "Dachschaden")
        context.insert(sperr); context.insert(roof)
        let todo = Todo(text: "Lieferung Dachrinne nachfassen", owner: .me, due: nil,
                        source: Source(kind: .mail, pointer: "x", messageID: "a"), origin: "a#1")
        context.insert(todo); todo.matter = roof
        let entry = Entry(title: "Liste für den Sperrmüll", from: "x@example.org", date: Date(), source: Source(kind: .mail, pointer: "y", messageID: "b"))
        entry.digest = "Gasherd, Bretter und eine Schubkarre kommen weg."
        context.insert(entry); entry.matter = sperr
        try context.save()

        #expect(MatterSearch.find("sperrmull", in: [sperr, roof]).map(\.matter.name) == ["Sperrmüll"])
        let byTask = MatterSearch.find("dachrinne", in: [sperr, roof])
        #expect(byTask.first?.matter === roof && byTask.first?.because == "Task: Lieferung Dachrinne nachfassen")
        #expect(MatterSearch.find("schubkarre", in: [sperr, roof]).first?.because == "Mail: Liste für den Sperrmüll")
        #expect(MatterSearch.find("umzug", in: [sperr, roof]).isEmpty)
    }
}
