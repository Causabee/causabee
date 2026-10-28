import { describe, expect, it } from "vitest";
import { anthropicUsage, costMicros, openAIUsage } from "../src/prices";

describe("what a request costs, as the app works it out", () => {
  it("counts input, output and the cache like Claude.Model.cost", () => {
    // Opus: 1,000 in at $5, 500 out at $25, 2,000 written at 1.25 × $5, 10,000 read at 0.1 × $5.
    const micros = costMicros("claude-opus-5", { input: 1000, output: 500, cacheWrite: 2000, cacheRead: 10_000, searches: 0 });
    expect(micros).toBe(5_000 + 12_500 + 12_500 + 5_000);
  });
  it("adds a cent a web search", () => {
    expect(costMicros("gpt-6.1-sol", { input: 0, output: 0, cacheWrite: 0, cacheRead: 0, searches: 2 })).toBe(20_000);
  });
  it("refuses a model it has no price for", () => {
    expect(costMicros("gpt-unknown", { input: 1, output: 1, cacheWrite: 0, cacheRead: 0, searches: 0 })).toBeNull();
  });
  it("reads Anthropic's usage", () => {
    const u = anthropicUsage({ usage: { input_tokens: 10, output_tokens: 20, cache_creation_input_tokens: 30, cache_read_input_tokens: 40, server_tool_use: { web_search_requests: 1 } } });
    expect(u).toEqual({ input: 10, output: 20, cacheWrite: 30, cacheRead: 40, searches: 1 });
  });
  it("reads OpenAI's usage, the cached part taken out of the input", () => {
    const u = openAIUsage({ usage: { input_tokens: 100, output_tokens: 7, input_tokens_details: { cached_tokens: 60 } }, output: [{ type: "web_search_call" }, { type: "message" }] });
    expect(u).toEqual({ input: 40, output: 7, cacheWrite: 0, cacheRead: 60, searches: 1 });
  });
});
