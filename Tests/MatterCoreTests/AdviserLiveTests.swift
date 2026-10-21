import Foundation
import SwiftData
import Testing
@testable import MatterCore

/// One real request to the adviser's model, only when a key is handed in (CAUSABEE_LIVE_KEY and
/// CAUSABEE_LIVE_MODEL): what the service answers, in its own words. Never runs otherwise.
@MainActor
struct AdviserLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CAUSABEE_LIVE_KEY"] != nil))
    func theAdviserAnswers() async throws {
        let env = ProcessInfo.processInfo.environment
        let model = Claude.Model.choices.first { $0.id == env["CAUSABEE_LIVE_MODEL"] } ?? .opus
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "pflege", name: "Pflege für Mama")
        context.insert(matter)
        for (text, owner) in [("Pflegegrad beantragen", Todo.Owner.me), ("Vertrag mit dem Pflegedienst unterschreiben", .me), ("Gutachter-Termin abwarten", .other)] {
            let todo = Todo(text: text, owner: owner, due: nil, source: Source(kind: .mail, pointer: "x", date: Date()), origin: text)
            context.insert(todo)
            todo.matter = matter
        }
        let facts = FactSheet.facts(for: [matter], today: MatterStatus.day(Date()), mails: 40)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("live-mapping-\(UUID().uuidString).json")
        do {
            let advice = try await AssistantAsk.advise(facts: facts, dismissed: [], owner: "Mara", today: MatterStatus.day(Date()),
                                                       mapping: url, claude: Claude(key: env["CAUSABEE_LIVE_KEY"]!), model: model)
            print("LIVE OK lines=\(advice.lines.count) proposals=\(advice.proposals.count) step=\(advice.step) research=\(advice.research) cost=\(advice.cost)")
        } catch {
            print("LIVE ERROR \(error)")
            throw error
        }
    }
}
