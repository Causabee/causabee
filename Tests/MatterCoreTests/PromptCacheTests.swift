import Foundation
import Testing
@testable import MatterCore

/// A question about a matter sends the matter's facts first, as a block of their own marked for
/// the cache, and the question after: a follow-up within minutes pays a tenth for the facts.
struct PromptCacheTests {
    private let user = AssistantPrompt.user(today: "2026-11-05", owner: "Alex", facts: "Open tasks:\n- T1 Call the movers",
                                            inHand: nil, earlier: [("Who has the key?", "Ms. Adler.")], question: "When does the van come?")

    @Test func theFactsComeFirstAndTheQuestionAfterTheBreak() throws {
        let parts = user.components(separatedBy: Claude.cacheBreak)
        #expect(parts.count == 2)
        #expect(parts[0].contains("T1 Call the movers") && !parts[0].contains("van come"))
        #expect(parts[1].contains("<question>") && parts[1].contains("<earlier>"))
    }

    @Test func solGetsOneTextWithoutTheMark() throws {
        for model in [Claude.Model.gptSol] {
            let body = Claude.body(model: model, system: "rules", user: user, schema: [:], effort: nil)
            let text = try #require((body["messages"] as? [[String: Any]])?.first?["content"] as? String)
            #expect(!text.contains("\u{1E}"))
            #expect(text.hasPrefix("Today: 2026-11-05."))
            let sent = Claude.openAIBody(body, model: model)["input"] as? String ?? ""
            #expect(sent.contains("van come"))
        }
    }

    @Test func aMailIsSentAsBefore() throws {
        let body = Claude.body(model: .gptSol, system: "rules", user: "One mail, no facts", schema: [:], effort: nil)
        #expect((body["messages"] as? [[String: Any]])?.first?["content"] as? String == "One mail, no facts")
    }
}
