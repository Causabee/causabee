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

    @Test(.enabled(if: ProcessInfo.processInfo.environment["CAUSABEE_LIVE_KEY"] != nil))
    func theAssistantOffersALookUp() async throws {
        let env = ProcessInfo.processInfo.environment
        let model = Claude.Model.choices.first { $0.id == env["CAUSABEE_LIVE_MODEL"] } ?? .opus
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "pflege", name: "Pflege für Mama")
        context.insert(matter)
        let todo = Todo(text: "Auf den Bescheid der Pflegekasse warten", owner: .other, due: nil,
                        source: Source(kind: .mail, pointer: "x", date: Date()), origin: "a")
        context.insert(todo)
        todo.matter = matter
        let facts = FactSheet.facts(for: [matter], today: MatterStatus.day(Date()))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("live-mapping-\(UUID().uuidString).json")
        let answer = try await AssistantAsk.ask(question: "Wie lange darf sich die Pflegekasse mit dem Bescheid Zeit lassen?", inHand: nil, earlier: [],
                                                facts: facts, owner: "Mara", today: MatterStatus.day(Date()), mapping: url,
                                                claude: Claude(key: env["CAUSABEE_LIVE_KEY"]!), model: model)
        let lookUps = answer.reply.cards.filter { $0.kind == .lookUp }
        print("LIVE ASK lines=\(answer.reply.lines.map(\.text)) lookUp=\(lookUps.map(\.text)) refusal=\(lookUps.map { WebLookup.refusal($0.text) ?? "none" })")
        #expect(!lookUps.isEmpty)
    }
}
