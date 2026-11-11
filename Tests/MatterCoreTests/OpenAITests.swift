import Foundation
import Testing
@testable import MatterCore

@Suite("The same request, in OpenAI's shape")
struct OpenAITests {
    @Test("Instructions and input as messages, a strict schema, as the Responses API takes them; the right key name")
    func body() throws {
        let schema: [String: Any] = ["type": "object", "properties": ["digest": ["type": "string"]], "required": ["digest"], "additionalProperties": false]
        let claude = Claude.body(model: .gptSol, system: "Write the digest.", user: "The mail.", schema: schema, effort: "low")
        let body = Claude.openAIBody(claude, model: .gptSol)
        #expect(body["model"] as? String == "gpt-6.1-sol")
        #expect(Claude.sentTexts(body).map(\.text) == ["Write the digest.", "The mail."])
        let format = try #require((body["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema" && format["strict"] as? Bool == true)
        #expect((format["schema"] as? [String: Any])?["required"] as? [String] == ["digest"])
        // The effort reaches OpenAI as its reasoning effort: without it every request thought at length.
        #expect((body["reasoning"] as? [String: Any])?["effort"] as? String == "low")
        // F004: each job its model, all of them OpenAI's, on the one key.
        #expect(Claude.Model.known == [.gptSol, .gptTerra, .gptLuna] && Claude.Model.known.allSatisfy { $0.isOpenAI && $0.keyName == "OPENAI_API_KEY" })
        #expect(Claude.Model.gptSol.isServing("gpt-6.1-sol-2026-09-01") && !Claude.Model.gptSol.isServing("gpt-6-astra"))
    }
}
