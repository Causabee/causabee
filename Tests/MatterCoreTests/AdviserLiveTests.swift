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
        let model = Claude.Model.choices.first { $0.id == env["CAUSABEE_LIVE_MODEL"] } ?? .gptSol
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
        let model = Claude.Model.choices.first { $0.id == env["CAUSABEE_LIVE_MODEL"] } ?? .gptSol
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

/// Two real questions about one made-up matter, only when a key is handed in (CAUSABEE_LIVE_KEY):
/// the second reads the matter's facts from OpenAI's cache, not only the instructions.
@MainActor
struct ChatCacheLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CAUSABEE_LIVE_KEY"] != nil))
    func theSecondQuestionReadsTheMatter() async throws {
        let env = ProcessInfo.processInfo.environment
        let context = ModelContext(try MatterSchema.container(at: nil))
        let matter = Matter(key: "umzug", name: "Umzug in die Lindenstraße")
        context.insert(matter)
        for n in 1...40 {
            let source = Source(kind: .mail, pointer: "x", messageID: "m\(n)@example", date: Date(timeIntervalSince1970: 1_790_000_000 + Double(n) * 86_400))
            let todo = Todo(text: "Kiste \(n) packen und beschriften: Küche, Bad oder Keller, mit Liste für den Umzugswagen", owner: .me,
                            due: nil, source: source, origin: "m\(n)#1")
            context.insert(todo)
            todo.matter = matter
            let entry = Entry(title: "Angebot \(n) der Spedition, Nummer A-\(1000 + n), für den Transport am Samstag", from: "Spedition <info@spedition.example>",
                              date: source.date, source: source)
            context.insert(entry)
            entry.matter = matter
        }
        try context.save()
        let facts = FactSheet.facts(for: [matter], today: "2026-11-11")
        let claude = Claude(key: env["CAUSABEE_LIVE_KEY"]!)
        var answers: [Claude.Answer] = []
        for question in ["Was ist offen?", "Welche Nummer hat das Angebot 7?"] {
            let user = AssistantPrompt.user(today: "2026-11-11", owner: "Mara", facts: facts.text, inHand: nil, earlier: [], question: question)
            let body = Claude.body(model: .gptSol, system: AssistantPrompt.system, user: user, schema: AssistantPrompt.schema, effort: "low")
            answers.append(try await claude.send(body, model: .gptSol))
        }
        for (n, a) in answers.enumerated() {
            print("LIVE \(n + 1): input \(a.inputTokens) written \(a.cacheWriteTokens) read \(a.cacheReadTokens) output \(a.outputTokens)")
        }
        #expect(answers[1].cacheReadTokens >= answers[0].cacheWriteTokens - 50, "the second question read back what the first wrote")
        #expect(answers[1].inputTokens < 1000, "only the question was paid in full")
    }
}
