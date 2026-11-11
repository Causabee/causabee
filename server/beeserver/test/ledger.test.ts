import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";

// A request paid from top-ups, once this month's Pro is used up, is two rows in the ledger: "spend"
// for what the month still carried, "spend_extra" for the rest. Its tokens are one request's, and
// count once; its money is both rows'.

/// A D1 whose account has used up its month and has top-ups left; it keeps every ledger row, and
/// answers the admin reports from those rows as SQLite would.
function topUpEnv() {
  const ledger: Record<string, any>[] = [];
  const statement = (sql: string, args: unknown[] = []): any => ({
    bind: (...a: unknown[]) => statement(sql, a),
    first: async () => {
      if (sql.includes("FROM tokens")) return { account: "acct-1" };
      if (sql.startsWith("SELECT kind, expires FROM accounts")) return { kind: "hand", expires: null };
      if (sql.includes("FROM accounts WHERE id")) return { id: "acct-1", kind: "hand", expires: null, anchor: "2026-11-01T00:00:00Z", allowance_micros: 4_500_000 };
      if (sql.includes("kind = 'spend'") && sql.includes("period = ?")) return { s: 4_500_000 };
      if (sql.includes("'topup', 'grant'")) return { s: 1_500_000 };
      if (sql.includes("SUM(")) return { s: 0 };
      if (sql.includes("COUNT(*) AS n")) return { n: 0 };
      return null;
    },
    run: async () => {
      if (sql.startsWith("INSERT OR IGNORE INTO ledger")) {
        const columns = sql.match(/\(([^)]*)\) VALUES/)![1].split(",").map((c) => c.trim());
        ledger.push(Object.fromEntries(columns.map((c, i) => [c, args[i]])));
      }
      return { success: true };
    },
    all: async () => ({ results: report(sql) }),
  });
  /// The two reports that add up requests and tokens, worked out over the rows kept.
  const report = (sql: string) => {
    const spent = (r: any) => r.kind === "spend" || r.kind === "spend_extra";
    if (sql.includes("GROUP BY day, job, model, tier")) {
      const where = sql.includes("kind IN ('spend', 'spend_extra')") ? spent : (r: any) => r.kind === "spend";
      const rows = ledger.filter(where);
      return [{
        requests: requests(sql, rows),
        micros: rows.reduce((s, r) => s + r.micros, 0),
        tokens_in: rows.reduce((s, r) => s + r.tokens_in, 0),
        tokens_out: rows.reduce((s, r) => s + r.tokens_out, 0),
      }];
    }
    if (sql.includes("GROUP BY model")) {
      const rows = ledger.filter(spent);
      return [{ requests: requests(sql, rows), micros: rows.reduce((s, r) => s + r.micros, 0) }];
    }
    return [];
  };
  const requests = (sql: string, rows: any[]) =>
    sql.includes("SUM(kind = 'spend') AS requests") ? rows.filter((r) => r.kind === "spend").length : rows.length;
  const DB = { prepare: (sql: string) => statement(sql), batch: async (s: any[]) => Promise.all(s.map((x) => x.run())) };
  return { env: { DB, OPENAI_API_KEY: "k", ANTHROPIC_API_KEY: "k", ADMIN_SECRET: "s" } as any, ledger };
}

function fakeOpenAI() {
  vi.stubGlobal("fetch", async (_url: string, init: RequestInit) => {
    const body = JSON.parse(String(init.body));
    return new Response(JSON.stringify({
      id: "resp_1", model: body.model, service_tier: body.service_tier ?? "default",
      usage: { input_tokens: 1000, output_tokens: 100, input_tokens_details: { cached_tokens: 0 } },
    }), { status: 200 });
  });
}

const ask = (env: any) =>
  worker.fetch(new Request("https://beeserver.causabee.app/v1/ai/openai", {
    method: "POST",
    headers: { authorization: "Bearer t", "content-type": "application/json", "causabee-job": "chat" },
    body: JSON.stringify({ input: "x" }),
  }), env);

const admin = (env: any, path: string) =>
  worker.fetch(new Request("https://beeserver.causabee.app" + path, { headers: { authorization: "Bearer s" } }), env);

afterEach(() => vi.unstubAllGlobals());

describe("A request paid from top-ups counts once", () => {
  it("writes its tokens on one row only; the money on the row it came from", async () => {
    const { env, ledger } = topUpEnv();
    fakeOpenAI();
    expect((await ask(env)).status).toBe(200);
    expect(ledger.map((r) => r.kind)).toEqual(["spend", "spend_extra"]);
    expect(ledger.reduce((s, r) => s + r.tokens_in, 0)).toBe(1000);
    expect(ledger.reduce((s, r) => s + r.tokens_out, 0)).toBe(100);
    expect(ledger[1].micros).toBeGreaterThan(0);
  });
  it("the month's report counts it as one request, with all its money", async () => {
    const { env, ledger } = topUpEnv();
    fakeOpenAI();
    await ask(env);
    const month = ledger[0].time.slice(0, 7);
    const report: any = await (await admin(env, "/admin/report?period=" + month)).json();
    expect(report.spent[0].requests).toBe(1);
    expect(report.spent[0].micros).toBe(ledger[0].micros + ledger[1].micros);
  });
  it("the report per job counts it as one request, with all its money and its tokens once", async () => {
    const { env, ledger } = topUpEnv();
    fakeOpenAI();
    await ask(env);
    const month = ledger[0].time.slice(0, 7);
    const report: any = await (await admin(env, "/admin/report?period=" + month)).json();
    expect(report.jobs[0].requests).toBe(1);
    expect(report.jobs[0].micros).toBe(ledger[0].micros + ledger[1].micros);
    expect(report.jobs[0].micros).toBeGreaterThan(0);
    expect(report.jobs[0].tokens_in).toBe(1000);
  });
});
