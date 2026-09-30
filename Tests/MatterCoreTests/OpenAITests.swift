import Foundation
import Testing
@testable import MatterCore

@Suite("The same request, in OpenAI's shape")
struct OpenAITests {
    @Test("Instructions, input and a strict schema, as the Responses API takes them; the right key name")
    func body() throws {
        let schema: [String: Any] = ["type": "object", "properties": ["digest": ["type": "string"]], "required": ["digest"], "additionalProperties": false]
        let claude = Claude.body(model: .gptSol, system: "Write the digest.", user: "The mail.", schema: schema, effort: "low")
        let body = Claude.openAIBody(claude, model: .gptSol)
        #expect(body["model"] as? String == "gpt-6.1-sol")
        #expect(body["instructions"] as? String == "Write the digest.")
        #expect(body["input"] as? String == "The mail.")
        let format = try #require((body["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema" && format["strict"] as? Bool == true)
        #expect((format["schema"] as? [String: Any])?["required"] as? [String] == ["digest"])
        #expect(claude["output_config"].flatMap { ($0 as? [String: Any])?["effort"] } == nil)
        #expect(Claude.Model.gptSol.keyName == "OPENAI_API_KEY" && Claude.Model.mistralLarge.keyName == "MISTRAL_API_KEY")
        #expect(Claude.Model.gptSol.isServing("gpt-6.1-sol-2026-09-01") && !Claude.Model.gptSol.isServing("gpt-6-astra"))
    }
}
