import Foundation
import Testing
@testable import MatterCore

/// Through the beeserver the request carries the Pro token and never a provider's key header;
/// without it, each provider gets its own address and key.
@Suite struct RelayTests {
    @Test func throughTheBeeserver() {
        let claude = Claude(key: "bee_test", relay: URL(string: "https://beeserver.example")!)
        let anthropic = claude.request(.anthropic)
        #expect(anthropic.url?.absoluteString == "https://beeserver.example/v1/ai/anthropic")
        #expect(anthropic.value(forHTTPHeaderField: "authorization") == "Bearer bee_test")
        #expect(anthropic.value(forHTTPHeaderField: "x-api-key") == nil)
        #expect(anthropic.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        let openai = claude.request(.openai, timeout: 300)
        #expect(openai.url?.absoluteString == "https://beeserver.example/v1/ai/openai")
        #expect(openai.timeoutInterval == 300)
        #expect(openai.httpMethod == "POST")
    }

    @Test func straightToTheProvider() {
        let claude = Claude(key: "sk-test")
        #expect(claude.request(.anthropic).url?.host == "api.anthropic.com")
        #expect(claude.request(.anthropic).value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(claude.request(.openai).url?.host == "api.openai.com")
        #expect(claude.request(.openai).value(forHTTPHeaderField: "authorization") == "Bearer sk-test")
    }

    @Test func noMistralThroughTheBeeserver() async {
        let claude = Claude(key: "bee_test", relay: URL(string: "https://beeserver.example")!)
        await #expect(throws: (any Error).self) {
            try await claude.send(["messages": []], model: .mistralLarge)
        }
    }
}
