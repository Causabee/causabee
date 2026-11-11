import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { jobs } from "../src/jobs";
import { costMicros, openAIUsage } from "../src/prices";

// F004: every request says its job, the job has its model, what may wait goes on Flex.

/// A D1 that knows the few questions the relay asks, and keeps what is written into the ledger.
function fakeEnv(kind = "apple", noJobColumn = false) {
  const ledger: Record<string, unknown>[] = [];
  const answer = (sql: string, args: unknown[]) => {
    if (sql.includes("FROM tokens")) return { account: "acct-1" };
    if (sql.startsWith("SELECT kind, expires FROM accounts")) return { kind, expires: new Date(Date.now() + 86_400_000).toISOString() };
    if (sql.includes("FROM accounts WHERE id")) return { id: "acct-1", kind, expires: null, anchor: "2026-11-01T00:00:00Z", allowance_micros: 4_500_000 };
    if (sql.includes("SUM(")) return { s: 0 };
    return null;
  };
  const statement = (sql: string, args: unknown[] = []) => ({
    bind: (...a: unknown[]) => statement(sql, a),
    first: async () => answer(sql, args),
    run: async () => {
      if (sql.startsWith("INSERT OR IGNORE INTO ledger")) {
        if (noJobColumn && sql.includes(" job,")) throw new Error("D1_ERROR: table ledger has no column named job");
        const columns = sql.match(/\(([^)]*)\) VALUES/)![1].split(",").map((c) => c.trim());
        ledger.push(Object.fromEntries(columns.map((c, i) => [c, args[i]])));
      }
      return { success: true };
    },
    all: async () => ({ results: [] }),
  });
  const DB = { prepare: (sql: string) => statement(sql), batch: async (s: any[]) => Promise.all(s.map((x) => x.run())) };
  return { env: { DB, OPENAI_API_KEY: "k", ANTHROPIC_API_KEY: "k", ADMIN_SECRET: "s" } as any, ledger };
}

/// OpenAI, as seen from the relay: every body it was sent, and the answers to give in turn.
function fakeOpenAI(...replies: Array<{ status: number; body: unknown }>) {
  const sent: any[] = [];
  vi.stubGlobal("fetch", async (_url: string, init: RequestInit) => {
    sent.push(JSON.parse(String(init.body)));
    const r = replies.shift() ?? { status: 200, body: answerFrom(sent.at(-1)) };
    return new Response(JSON.stringify(r.body), { status: r.status });
  });
  return sent;
}

const answerFrom = (body: any, tier = body.service_tier ?? "default") => ({
  id: "resp_" + Math.random().toString(36).slice(2),
  model: body.model,
  service_tier: tier,
  usage: { input_tokens: 1000, output_tokens: 100, input_tokens_details: { cached_tokens: 0 } },
});

const ask = (env: any, body: Record<string, unknown>, job?: string) =>
  worker.fetch(
    new Request("https://beeserver.causabee.app/v1/ai/openai", {
      method: "POST",
      headers: { authorization: "Bearer t", "content-type": "application/json", ...(job ? { "causabee-job": job } : {}) },
      body: JSON.stringify(body),
    }),
    env,
  );

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("F004 AC-1 · A request's job is in the ledger", () => {
  it("writes the job beside the model", async () => {
    const { env, ledger } = fakeEnv();
    fakeOpenAI();
    const r = await ask(env, { input: "x" }, "brief");
    expect(r.status).toBe(200);
    expect(ledger).toHaveLength(1);
    expect(ledger[0]).toMatchObject({ job: "brief", model: jobs.brief.model, kind: "spend" });
  });
  it("counts a request from an older build, without a job, as unknown, and answers it with Sol", async () => {
    const { env, ledger } = fakeEnv();
    fakeOpenAI();
    const r = await ask(env, { model: "gpt-6.1-sol", input: "x" });
    expect(r.status).toBe(200);
    expect(ledger[0]).toMatchObject({ job: "unknown", model: "gpt-6.1-sol" });
  });
  it("still counts the request, without its job, when the migration is not applied", async () => {
    const { env, ledger } = fakeEnv("apple", true);
    fakeOpenAI();
    vi.spyOn(console, "error").mockImplementation(() => {});
    const r = await ask(env, { input: "x" }, "read");
    expect(r.status).toBe(200);
    expect(ledger).toHaveLength(1);
    expect(ledger[0].job).toBeUndefined();
    expect(ledger[0].micros).toBeGreaterThan(0);
  });
});

describe("F004 AC-2 · A model the table does not give the job is refused", () => {
  it("knows the four jobs, each with a priced model", () => {
    expect(Object.keys(jobs).sort()).toEqual(["brief", "chat", "digest", "read"]);
    for (const j of Object.values(jobs)) expect(costMicros(j.model, { input: 1, output: 1, cacheWrite: 0, cacheRead: 0, searches: 0 })).not.toBeNull();
  });
  it("sets the job's model when the request names none", async () => {
    const { env } = fakeEnv();
    const sent = fakeOpenAI();
    await ask(env, { input: "x" }, "read");
    expect(sent[0].model).toBe(jobs.read.model);
  });
  it("refuses another model for the job, and sends nothing on", async () => {
    const { env, ledger } = fakeEnv();
    const sent = fakeOpenAI();
    const r = await ask(env, { model: "claude-opus-5", input: "x" }, "chat");
    expect(r.status).toBe(400);
    expect(await r.json()).toMatchObject({ error: "model_not_offered" });
    expect(sent).toHaveLength(0);
    expect(ledger).toHaveLength(0);
  });
  it("refuses a job it does not know", async () => {
    const { env } = fakeEnv();
    fakeOpenAI();
    const r = await ask(env, { input: "x" }, "everything");
    expect(r.status).toBe(400);
  });
  it("keys the cache by the account, never by the text", async () => {
    const { env } = fakeEnv();
    const sent = fakeOpenAI();
    await ask(env, { input: "a" }, "read");
    await ask(env, { input: "b" }, "brief");
    expect(sent[0].prompt_cache_key).toMatch(/^[0-9a-f]{32}$/);
    expect(sent[1].prompt_cache_key).toBe(sent[0].prompt_cache_key);
    expect(sent[0].prompt_cache_key).not.toContain("acct-1");
  });
});

describe("F004 AC-4 · What may wait goes on Flex, and once more without it when Flex is busy", () => {
  it("sends reading, digests and the brief on Flex; never the chat", async () => {
    const { env } = fakeEnv();
    const sent = fakeOpenAI();
    for (const job of ["read", "digest", "brief", "chat"]) await ask(env, { input: "x" }, job);
    expect(sent.map((b) => b.service_tier)).toEqual(["flex", "flex", "flex", undefined]);
    expect(jobs.chat.flex).toBe(false);
  });
  it("asks again at the normal tier when Flex answers 429, and counts only what was answered", async () => {
    const { env, ledger } = fakeEnv();
    const sent = fakeOpenAI({ status: 429, body: { error: { message: "Resource Unavailable" } } });
    const r = await ask(env, { input: "x" }, "read");
    expect(r.status).toBe(200);
    expect(sent).toHaveLength(2);
    expect(sent[0].service_tier).toBe("flex");
    expect(sent[1].service_tier).toBeUndefined();
    expect(ledger).toHaveLength(1);
  });
  it("counts Flex at half the price, and the normal tier at the full price", async () => {
    const usage = { input: 1000, output: 100, cacheWrite: 0, cacheRead: 0, searches: 0 };
    const full = costMicros("gpt-6.1-sol", usage)!;
    expect(costMicros("gpt-6.1-sol", usage, "flex")).toBe(Math.ceil(full / 2));
    const { env, ledger } = fakeEnv();
    fakeOpenAI();
    await ask(env, { input: "x" }, "brief");
    await ask(env, { input: "x" }, "chat");
    const brief = costMicros(jobs.brief.model, usage, "flex");
    const chat = costMicros(jobs.chat.model, usage);
    expect(ledger.map((r) => r.micros)).toEqual([brief, chat]);
    expect(ledger.map((r) => r.tier)).toEqual(["flex", "default"]);
  });
});

describe("F004 AC-5 · The cache is counted as OpenAI charges it", () => {
  it("takes the cache write out of the input and prices it at 1.25×", () => {
    const u = openAIUsage({ usage: { input_tokens: 12000, output_tokens: 10, input_tokens_details: { cached_tokens: 4000, cache_write_tokens: 7000 } } });
    expect(u).toEqual({ input: 1000, output: 10, cacheWrite: 7000, cacheRead: 4000, searches: 0 });
  });
  it("prices a cached read of Terra at its own price, $0.05 a million", () => {
    expect(costMicros("gpt-6.1-terra", { input: 0, output: 0, cacheWrite: 0, cacheRead: 1_000_000, searches: 0 })).toBe(50_000);
    expect(costMicros("gpt-6-luna", { input: 1_000_000, output: 1_000_000, cacheWrite: 0, cacheRead: 1_000_000, searches: 0 })).toBe(100_000 + 500_000 + 10_000);
  });
  it("prices a cached read of Sol at $0.10 a million, a twentieth of its input, as OpenAI charges it", () => {
    expect(costMicros("gpt-6.1-sol", { input: 0, output: 0, cacheWrite: 0, cacheRead: 1_000_000, searches: 0 })).toBe(100_000);
  });
});
