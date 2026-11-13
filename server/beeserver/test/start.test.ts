import { describe, expect, it } from "vitest";
import worker, { giveStart, type AppDownload } from "../src/index";

// F008 AC-14: one top-up's worth, given once per Apple account at its first start — in the App
// Store only for downloads from START_CREDIT_FROM on, in TestFlight always; given again only after
// the owner's /admin/start-forget, which reaches TestFlight's alone.

/// A D1 that keeps accounts and ledger rows, and answers what the start credit asks of it.
function db() {
  const accounts = new Map<string, Record<string, unknown>>();
  const ledger: Record<string, any>[] = [];
  const statement = (sql: string, args: unknown[] = []): any => ({
    bind: (...a: unknown[]) => statement(sql, a),
    first: async () => {
      if (sql.startsWith("SELECT account FROM ledger WHERE ref")) {
        const row = ledger.find((r) => r.ref === args[0]);
        return row ? { account: row.account } : null;
      }
      if (sql.includes("FROM accounts WHERE id")) return accounts.get(args[0] as string) ?? null;
      return null;
    },
    run: async () => {
      if (sql.startsWith("INSERT OR IGNORE INTO accounts")) {
        if (!accounts.has(args[0] as string)) accounts.set(args[0] as string, { id: args[0], kind: "credit", allowance_micros: 0 });
      } else if (sql.startsWith("INSERT OR IGNORE INTO ledger")) {
        const columns = sql.match(/\(([^)]*)\) VALUES/)![1].split(",").map((c) => c.trim());
        const values = [...args];
        const row = Object.fromEntries(columns.map((c) => [c, c === "kind" ? "grant" : values.shift()]));
        if (!ledger.some((r) => r.ref === row.ref)) ledger.push(row);
      } else if (sql.startsWith("DELETE FROM ledger")) {
        const before = ledger.length;
        for (let i = ledger.length - 1; i >= 0; i--) {
          if (ledger[i].account === args[0] && ledger[i].kind === "grant" && String(ledger[i].ref).startsWith("start:sandbox:")) ledger.splice(i, 1);
        }
        return { success: true, meta: { changes: before - ledger.length } };
      }
      return { success: true, meta: { changes: 1 } };
    },
  });
  return { accounts, ledger, DB: { prepare: (sql: string) => statement(sql) } };
}

const env = (from?: string) => {
  const d = db();
  return { d, env: { DB: d.DB, OPENAI_API_KEY: "", ANTHROPIC_API_KEY: "", ADMIN_SECRET: "secret", START_CREDIT_FROM: from } as any };
};
const account = "7d1f6c2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f";
const day = 86_400_000;
const store = (purchased: number, id = "2000000123"): AppDownload =>
  ({ bundleId: "de.chille.causabee", appTransactionId: id, originalPurchaseDate: purchased, receiptType: "Production" });
const testFlight = (id = "7000000001"): AppDownload =>
  ({ bundleId: "de.chille.causabee", appTransactionId: id, originalPurchaseDate: Date.parse("2026-01-01"), receiptType: "Sandbox" });

describe("F008 AC-14 · The start credit", () => {
  it("gives one top-up's worth to a new download from the App Store, once", async () => {
    const { d, env: e } = env("2026-12-01");
    const first = await giveStart(e, store(Date.parse("2026-12-03")), account);
    expect(first).toEqual({ account: "app:" + account, given: true });
    expect(d.ledger).toHaveLength(1);
    expect(d.ledger[0]).toMatchObject({ account: "app:" + account, kind: "grant", micros: 1_500_000, ref: "start:2000000123" });
    // The same Apple account again — another device, a new install, another app id: no second one.
    const again = await giveStart(e, store(Date.parse("2026-12-03")), "11111111-2222-4333-8444-555555555555");
    expect(again).toEqual({ account: "app:" + account, given: false, why: "given_before" });
    expect(d.ledger).toHaveLength(1);
  });

  it("gives none to a download from before the day, nor with no day set", async () => {
    const { d, env: e } = env("2026-12-01");
    expect((await giveStart(e, store(Date.parse("2026-11-30")), account)).why).toBe("not_new");
    const { env: unset } = env(undefined);
    expect((await giveStart(unset, store(Date.parse("2026-12-03")), account)).why).toBe("not_new");
    expect(d.ledger).toHaveLength(0);
  });

  it("gives none to another app, a record with no download id, an Xcode build or no account id", async () => {
    const { d, env: e } = env("2026-01-01");
    expect((await giveStart(e, { ...store(Date.now()), bundleId: "com.other" }, account)).why).toBe("not_this_app");
    expect((await giveStart(e, { ...store(Date.now()), appTransactionId: undefined }, account)).why).toBe("no_download_id");
    expect((await giveStart(e, { ...store(Date.now()), receiptType: "Xcode" }, account)).why).toBe("not_new");
    expect((await giveStart(e, store(Date.now()), "not-a-uuid")).why).toBe("no_account");
    expect(d.ledger).toHaveLength(0);
  });

  it("gives TestFlight's whatever the day — and again after the owner forgets it, TestFlight's alone", async () => {
    const { d, env: e } = env(undefined);
    expect((await giveStart(e, testFlight(), account)).given).toBe(true);
    expect(d.ledger[0].ref).toBe("start:sandbox:7000000001");
    expect((await giveStart(e, testFlight(), account)).given).toBe(false);
    const forget = await worker.fetch(new Request("https://bee.test/admin/start-forget", {
      method: "POST", headers: { authorization: "Bearer secret" }, body: JSON.stringify({ account: "app:" + account }),
    }), e);
    expect(await forget.json()).toEqual({ account: "app:" + account, forgotten: 1 });
    expect((await giveStart(e, testFlight(), account)).given).toBe(true);
  });

  it("never forgets the App Store's", async () => {
    const { d, env: e } = env("2026-12-01");
    await giveStart(e, store(Date.parse("2026-12-03")), account);
    await worker.fetch(new Request("https://bee.test/admin/start-forget", {
      method: "POST", headers: { authorization: "Bearer secret" }, body: JSON.stringify({ account: "app:" + account }),
    }), e);
    expect(d.ledger).toHaveLength(1);
  });

  it("refuses a record not signed by Apple, saying only why", async () => {
    const { env: e } = env("2026-12-01");
    const answer = await worker.fetch(new Request("https://bee.test/v1/start", {
      method: "POST", body: JSON.stringify({ download: "a.b.c", account }),
    }), e);
    expect(answer.status).toBe(200);
    expect(await answer.json()).toEqual({ given: false, why: "not_signed_by_apple" });
  });
});
