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

    /// GPT-6.1 writes into its cache only up to a mark, and reads back only what was written: sent as
    /// one text, every request was written whole at 1.25× the input price, and only the instructions
    /// were ever read back — never a matter's facts (the ledger, 11 November).
    @Test("OpenAI is told where the cache ends: after the instructions, and after the matter's facts")
    func openAIMarksTheCache() throws {
        let body = Claude.openAIBody(Claude.body(model: .gptSol, system: "rules", user: user, schema: [:], effort: nil), model: .gptSol)
        #expect((body["prompt_cache_options"] as? [String: Any])?["mode"] as? String == "explicit")
        #expect(body["instructions"] == nil, "OpenAI takes no mark on the top-level instructions")
        let sent = Claude.sentTexts(body)
        #expect(sent.map(\.role) == ["developer", "user", "user"])
        #expect(sent.map(\.marked) == [true, true, false], "the question is not written into the cache")
        try #require(sent.count == 3)
        #expect(sent[0].text == "rules")
        #expect(sent[1].text.hasPrefix("Today: 2026-11-05.") && sent[1].text.contains("T1 Call the movers") && !sent[1].text.contains("van come"))
        #expect(sent[2].text.contains("<earlier>") && sent[2].text.contains("<question>") && sent[2].text.contains("van come"))
        #expect(!sent.map(\.text).joined().contains("\u{1E}"))
    }

    @Test("An item with no facts before it: the instructions marked, the item not")
    func anItemMarksTheInstructionsOnly() throws {
        let body = Claude.openAIBody(Claude.body(model: .gptTerra, system: "rules", user: "One mail, no facts", schema: [:], effort: "low"), model: .gptTerra)
        let sent = Claude.sentTexts(body)
        #expect(sent.map(\.role) == ["developer", "user"])
        #expect(sent.map(\.marked) == [true, false])
        #expect(sent.map(\.text) == ["rules", "One mail, no facts"])
    }

    @Test func aMailIsSentAsBefore() throws {
        let body = Claude.body(model: .gptSol, system: "rules", user: "One mail, no facts", schema: [:], effort: nil)
        #expect((body["messages"] as? [[String: Any]])?.first?["content"] as? String == "One mail, no facts")
    }
}

extension Claude {
    /// What an OpenAI body sends, block by block: who says it, its text, and whether the cache is marked after it.
    static func sentTexts(_ body: [String: Any]) -> [(role: String, text: String, marked: Bool)] {
        ((body["input"] as? [[String: Any]]) ?? []).flatMap { message in
            ((message["content"] as? [[String: Any]]) ?? []).map { block in
                (role: message["role"] as? String ?? "", text: block["text"] as? String ?? "",
                 marked: (block["prompt_cache_breakpoint"] as? [String: Any])?["mode"] as? String == "explicit")
            }
        }
    }
}
