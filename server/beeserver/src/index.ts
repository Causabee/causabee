// The beeserver: Causabee Pro's way to the bigger AI. The app sends the same request it sends a
// provider today; the server checks who asks and whether this month's Pro has room, adds
// Causabee's own key, passes the request on unchanged, and writes what it cost into the ledger.
// The text passing through is disguised already, and none of it is stored or logged.
//
// Step 2 of concept/pro-service.md: a Pro subscription, as the App Store signed it, is redeemed
// for a token; every request checks it has not ended; a top-up bought in the app adds to the
// month, counted once. Accounts made by hand with the admin secret stay, for testing.

import { NotApple, verifySigned, verifyTransaction, type AppleTransaction } from "./apple";
import { cycle } from "./cycle";
import { newEnd, replaces } from "./notifications";
import { anthropicUsage, costMicros, openAIUsage, prices, type Usage } from "./prices";

export interface Env {
  DB: D1Database;
  OPENAI_API_KEY: string;
  ANTHROPIC_API_KEY: string;
  ADMIN_SECRET: string;
}

/// No answer may run away: the app asks for at most 8,000 tokens today.
const mostOutputTokens = 16_000;

/// The app, and what it sells.
const bundleId = "de.chille.causabee";
const proProducts = ["de.chille.causabee.pro.monthly"];
/// Plus, in the same subscription group as Pro: renewed in Pro's place, it ends Pro.
const plusProducts = ["de.chille.causabee.matters.monthly", "de.chille.causabee.matters.yearly"];
/// A top-up adds what it says here, in micro-dollars — a third of a Pro month — kept until used.
export const topUps: Record<string, number> = { "de.chille.causabee.pro.topup": 1_500_000 };
/// A subscriber's month: four dollars fifty of the providers' prices. Per dollar of AI it is
/// better than a top-up (€7.99 for $4.50 against €2.99 for $1.50), so Pro stays the plan to have.
const allowanceMicros = 4_500_000;
/// Pro goes on this long past the end Apple last told: a renewal is seen when the app next opens.
const graceMs = 3 * 86_400_000;
/// What a subscriber's requests may use: the plan picks the model, and the month goes furthest with Sol.
const subscriberModels = ["gpt-6.1-sol"];

const json = (body: unknown, status = 200, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...headers } });

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    try {
      if (url.pathname.startsWith("/admin/")) return await admin(request, url, env);
      if (request.method === "GET" && url.pathname === "/v1/allowance") {
        const account = await who(request, env);
        if (!account) return json({ error: "unauthorized" }, 401);
        return json(await allowance(env, account));
      }
      if (request.method === "POST" && url.pathname === "/v1/apple/notifications") return await notification(request, env);
      if (request.method === "POST" && url.pathname === "/v1/subscribe") return await subscribe(request, env);
      if (request.method === "POST" && url.pathname === "/v1/topup") return await topUp(request, env);
      if (request.method === "POST" && url.pathname === "/v1/ai/openai") return await relay(request, env, "openai");
      if (request.method === "POST" && url.pathname === "/v1/ai/anthropic") return await relay(request, env, "anthropic");
      if (url.pathname === "/") return new Response("beeserver\n");
      return json({ error: "not_found" }, 404);
    } catch (error) {
      // Never the request's body in a log: only what went wrong, in general.
      console.error("beeserver error", (error as Error)?.name ?? "error");
      return json({ error: "server_error" }, 500);
    }
  },
};

// MARK: Who asks

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/// The account behind the bearer token, if the token is known, not revoked and the account not blocked.
async function who(request: Request, env: Env): Promise<string | null> {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const row = await env.DB.prepare(
    "SELECT t.account FROM tokens t JOIN accounts a ON a.id = t.account WHERE t.hash = ? AND t.revoked = 0 AND a.blocked = 0",
  ).bind(await sha256(token)).first<{ account: string }>();
  return row?.account ?? null;
}

// MARK: The month's room

const day = (date = new Date()) => date.toISOString().slice(0, 10);

interface Account {
  id: string;
  kind: string; // hand | apple | credit
  expires: string | null;
  anchor: string | null;
  allowance_micros: number;
}

async function account(env: Env, id: string): Promise<Account | null> {
  return env.DB.prepare("SELECT id, kind, expires, anchor, allowance_micros FROM accounts WHERE id = ?").bind(id).first<Account>();
}

/// The month an account counts in now: a subscriber's from the day Pro was bought.
async function period(env: Env, id: string): Promise<string> {
  return cycle((await account(env, id))?.anchor).key;
}

interface Room {
  allowance: number;
  spentThisMonth: number;
  spentToday: number;
  extraLeft: number;
}

async function room(env: Env, id: string): Promise<Room> {
  const a = await account(env, id);
  const month = await env.DB.prepare(
    "SELECT COALESCE(SUM(micros), 0) AS s FROM ledger WHERE account = ? AND period = ? AND kind = 'spend'",
  ).bind(id, cycle(a?.anchor).key).first<{ s: number }>();
  const today = await env.DB.prepare(
    "SELECT COALESCE(SUM(micros), 0) AS s FROM ledger WHERE account = ? AND kind IN ('spend', 'spend_extra') AND substr(time, 1, 10) = ?",
  ).bind(id, day()).first<{ s: number }>();
  // A refunded top-up is taken back from what is left.
  const extra = await env.DB.prepare(
    "SELECT COALESCE(SUM(CASE WHEN kind IN ('topup', 'grant') THEN micros WHEN kind IN ('spend_extra', 'refund') THEN -micros ELSE 0 END), 0) AS s FROM ledger WHERE account = ?",
  ).bind(id).first<{ s: number }>();
  return { allowance: a?.allowance_micros ?? 0, spentThisMonth: month?.s ?? 0, spentToday: today?.s ?? 0, extraLeft: extra?.s ?? 0 };
}

/// What the app shows: shares, never money. `monthUsed` 0…1 of this month's Pro; `extra` whether
/// top-ups are left after it, and `extraShare` how much of them, in Pro months.
async function allowance(env: Env, id: string) {
  const r = await room(env, id);
  const a = await account(env, id);
  const monthUsed = r.allowance > 0 ? Math.min(1, r.spentThisMonth / r.allowance) : 1;
  return {
    monthUsed: Math.round(monthUsed * 1000) / 1000,
    renewsOn: cycle(a?.anchor).renewsOn,
    extra: r.extraLeft > 0,
    extraShare: Math.round((Math.max(0, r.extraLeft) / allowanceMicros) * 1000) / 1000,
    kind: a?.kind ?? "hand",
  };
}

// MARK: Passing a request on

async function relay(request: Request, env: Env, provider: "openai" | "anthropic"): Promise<Response> {
  const account = await who(request, env);
  if (!account) return json({ error: "unauthorized" }, 401);
  const kind = await env.DB.prepare("SELECT kind, expires FROM accounts WHERE id = ?").bind(account).first<{ kind: string; expires: string | null }>();
  // Ended: what is left of top-ups still carries on, as for anyone without Pro.
  const ended = kind?.kind === "apple" && (!kind.expires || Date.parse(kind.expires) + graceMs < Date.now());

  const body = (await request.json()) as Record<string, any>;
  const model = String(body.model ?? "");
  if (!prices[model] || (kind?.kind !== "hand" && !subscriberModels.includes(model))) return json({ error: "model_not_offered", model }, 400);
  if (provider === "openai") body.max_output_tokens = Math.min(Number(body.max_output_tokens ?? mostOutputTokens), mostOutputTokens);
  else body.max_tokens = Math.min(Number(body.max_tokens ?? mostOutputTokens), mostOutputTokens);

  const r = await room(env, account);
  const monthLeft = ended ? 0 : r.allowance - r.spentThisMonth;
  if (monthLeft <= 0 && r.extraLeft <= 0) {
    return json({ error: ended ? "subscription_ended" : "allowance_used", ...(await allowance(env, account)) }, 402);
  }
  // A day may use at most a quarter of the month: a loop gone wrong cannot eat it in an afternoon.
  if (r.spentToday >= r.allowance / 4 && r.extraLeft <= 0) return json({ error: "daily_limit" }, 429);

  const upstream =
    provider === "openai"
      ? await fetch("https://api.openai.com/v1/responses", {
          method: "POST",
          headers: { "content-type": "application/json", authorization: `Bearer ${env.OPENAI_API_KEY}` },
          body: JSON.stringify(body),
        })
      : await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-api-key": env.ANTHROPIC_API_KEY,
            "anthropic-version": request.headers.get("anthropic-version") ?? "2023-06-01",
            ...(request.headers.get("anthropic-beta") ? { "anthropic-beta": request.headers.get("anthropic-beta")! } : {}),
          },
          body: JSON.stringify(body),
        });

  const text = await upstream.text();
  if (!upstream.ok) return new Response(text, { status: upstream.status, headers: { "content-type": "application/json" } });

  const answer = JSON.parse(text);
  const usage: Usage = provider === "openai" ? openAIUsage(answer) : anthropicUsage(answer);
  const cost = costMicros(model, usage) ?? 0;
  await spend(env, account, await period(env, account), model, usage, cost, String(answer.id ?? crypto.randomUUID()), monthLeft);
  const now = await allowance(env, account);
  return new Response(text, {
    status: 200,
    headers: { "content-type": "application/json", "causabee-month-used": String(now.monthUsed), "causabee-renews-on": now.renewsOn },
  });
}

/// Into the ledger: from this month's allowance first, the rest from top-ups.
async function spend(env: Env, account: string, month: string, model: string, usage: Usage, cost: number, ref: string, monthLeft: number) {
  const fromMonth = Math.max(0, Math.min(cost, monthLeft));
  const fromExtra = cost - fromMonth;
  const time = new Date().toISOString();
  const row = (kind: string, micros: number, suffix: string) =>
    env.DB.prepare(
      "INSERT OR IGNORE INTO ledger (account, period, kind, micros, ref, model, tokens_in, tokens_out, tokens_cached, searches, time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    ).bind(account, month, kind, micros, ref + suffix, model, usage.input + usage.cacheWrite, usage.output, usage.cacheRead, usage.searches, time);
  const rows = [row("spend", fromMonth, "")];
  if (fromExtra > 0) rows.push(row("spend_extra", fromExtra, "#extra"));
  await env.DB.batch(rows);
}

// MARK: Bought in the app

async function transaction(request: Request): Promise<AppleTransaction | Response> {
  const { transaction: jws } = (await request.json()) as { transaction?: string };
  if (!jws) return json({ error: "no_transaction" }, 400);
  try {
    const t = await verifyTransaction(jws);
    if (t.bundleId !== bundleId) return json({ error: "not_this_app" }, 400);
    if (t.revocationDate) return json({ error: "refunded" }, 402);
    return t;
  } catch (error) {
    if (error instanceof NotApple) return json({ error: "not_signed_by_apple" }, 400);
    throw error;
  }
}

/// The account a purchase belongs to: by the app's own id for the Apple Account, sent with each
/// purchase — so Plus's top-ups and a later Pro land in one account — or, for a purchase made
/// before the app sent one, by the subscription's first transaction.
function accountFor(t: AppleTransaction): string {
  return t.appAccountToken ? "app:" + t.appAccountToken.toLowerCase() : "apple:" + t.originalTransactionId;
}

/// A Pro subscription, signed by the App Store, for a token. Renewals, and every device of the
/// same Apple Account, land in one account. Sent again with a renewal, it only moves the end;
/// with the account's own token it makes no new one.
async function subscribe(request: Request, env: Env): Promise<Response> {
  const known = await who(request, env);
  const t = await transaction(request);
  if (t instanceof Response) return t;
  if (!proProducts.includes(t.productId)) return json({ error: "not_pro" }, 400);
  if (!t.expiresDate || t.expiresDate + graceMs < Date.now()) return json({ error: "subscription_ended" }, 402);
  const id = accountFor(t);
  const now = new Date().toISOString();
  const expires = new Date(t.expiresDate).toISOString();
  const anchor = new Date(t.originalPurchaseDate ?? t.purchaseDate).toISOString();
  await env.DB.prepare("INSERT OR IGNORE INTO accounts (id, created, allowance_micros, kind, expires, anchor, orig_tx) VALUES (?, ?, ?, 'apple', ?, ?, ?)")
    .bind(id, now, allowanceMicros, expires, anchor, t.originalTransactionId).run();
  // An account of top-ups becomes a subscriber's, its top-ups kept; the end only ever moves later.
  await env.DB.prepare(
    "UPDATE accounts SET kind = 'apple', allowance_micros = ?, orig_tx = ?, anchor = COALESCE(anchor, ?), expires = CASE WHEN expires IS NULL OR expires < ? THEN ? ELSE expires END WHERE id = ?",
  ).bind(allowanceMicros, t.originalTransactionId, anchor, expires, expires, id).run();
  const token = known === id ? null : await newToken(env, id, "App Store · " + t.environment);
  return json({ token, expires, ...(await allowance(env, id)) });
}

/// A top-up bought in the app: added once, however often it is sent — the purchase is the ledger's
/// ref. Bought without Pro, it opens an account of its own, and the answer brings its token.
async function topUp(request: Request, env: Env): Promise<Response> {
  const known = await who(request, env);
  const t = await transaction(request);
  if (t instanceof Response) return t;
  const micros = topUps[t.productId];
  if (!micros) return json({ error: "not_a_topup" }, 400);
  let id = known;
  let token: string | null = null;
  if (!id) {
    if (!t.appAccountToken) return json({ error: "unauthorized" }, 401);
    id = accountFor(t);
    await env.DB.prepare("INSERT OR IGNORE INTO accounts (id, created, allowance_micros, kind) VALUES (?, ?, 0, 'credit')")
      .bind(id, new Date().toISOString()).run();
    token = await newToken(env, id, "App Store · " + t.environment);
  }
  await env.DB.prepare("INSERT OR IGNORE INTO ledger (account, period, kind, micros, ref, model, time) VALUES (?, ?, 'topup', ?, ?, ?, ?)")
    .bind(id, await period(env, id), micros, "apple:" + t.transactionId, t.productId, new Date().toISOString()).run();
  return json({ token, ...(await allowance(env, id)) });
}

// MARK: Told by the App Store

/// App Store Server Notifications, version 2: renewals, ends, refunds — signed by Apple like a
/// purchase, and believed only when the signature holds. Answered 200 when understood or of no
/// concern, so Apple does not send it again.
async function notification(request: Request, env: Env): Promise<Response> {
  const { signedPayload } = (await request.json()) as { signedPayload?: string };
  if (!signedPayload) return json({ error: "no_payload" }, 400);
  let note: { notificationType: string; subtype?: string; data?: { bundleId?: string; signedTransactionInfo?: string; signedRenewalInfo?: string } };
  let t: AppleTransaction;
  let renewal: { gracePeriodExpiresDate?: number } | undefined;
  try {
    note = await verifySigned(signedPayload);
    if (note.data?.bundleId !== bundleId || !note.data.signedTransactionInfo) return json({ ignored: true });
    t = await verifyTransaction(note.data.signedTransactionInfo);
    if (note.data.signedRenewalInfo) renewal = await verifySigned(note.data.signedRenewalInfo);
  } catch (error) {
    if (error instanceof NotApple) return json({ error: "not_signed_by_apple" }, 400);
    throw error;
  }
  const now = new Date().toISOString();

  // A top-up refunded: taken back from what is left of it.
  if (topUps[t.productId]) {
    if (note.notificationType !== "REFUND") return json({ ignored: true });
    const bought = await env.DB.prepare("SELECT account, micros FROM ledger WHERE ref = ? AND kind = 'topup'")
      .bind("apple:" + t.transactionId).first<{ account: string; micros: number }>();
    if (!bought) return json({ ignored: true });
    await env.DB.prepare("INSERT OR IGNORE INTO ledger (account, period, kind, micros, ref, model, time) VALUES (?, ?, 'refund', ?, ?, ?, ?)")
      .bind(bought.account, await period(env, bought.account), bought.micros, "apple:refund:" + t.transactionId, t.productId, now).run();
    return json({ refunded: true });
  }

  const isPro = proProducts.includes(t.productId);
  if (!isPro && !plusProducts.includes(t.productId)) return json({ ignored: true });
  const holder = await env.DB.prepare("SELECT id, expires FROM accounts WHERE orig_tx = ? OR id = ?")
    .bind(t.originalTransactionId, accountFor(t)).first<{ id: string; expires: string | null }>();
  if (!holder) return json({ ignored: true });
  const end = newEnd(note.notificationType, note.subtype, isPro, t, renewal);
  if (end === null) return json({ unchanged: true });
  const known = holder.expires ? Date.parse(holder.expires) : 0;
  // A renewal only lengthens Pro; an end, a refund or Plus in its place shortens it.
  const next = replaces(note.notificationType, isPro) ? Math.min(end, known || end) : Math.max(end, known);
  if (next !== known) await env.DB.prepare("UPDATE accounts SET expires = ? WHERE id = ?").bind(new Date(next).toISOString(), holder.id).run();
  return json({ account: holder.id, expires: new Date(next).toISOString() });
}

async function newToken(env: Env, account: string, label: string): Promise<string> {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const token = "bee_" + btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  await env.DB.prepare("INSERT INTO tokens (hash, account, label, created) VALUES (?, ?, ?, ?)").bind(await sha256(token), account, label, new Date().toISOString()).run();
  // Shown this once: only its hash is kept.
  return token;
}

// MARK: By hand, with the admin secret

async function admin(request: Request, url: URL, env: Env): Promise<Response> {
  if (!env.ADMIN_SECRET || request.headers.get("authorization") !== `Bearer ${env.ADMIN_SECRET}`) return json({ error: "unauthorized" }, 401);
  const now = new Date().toISOString();

  if (request.method === "POST" && url.pathname === "/admin/accounts") {
    const { id, allowanceMicros = 4_500_000 } = (await request.json()) as { id: string; allowanceMicros?: number };
    await env.DB.prepare("INSERT OR IGNORE INTO accounts (id, created, allowance_micros) VALUES (?, ?, ?)").bind(id, now, allowanceMicros).run();
    await env.DB.prepare("UPDATE accounts SET allowance_micros = ? WHERE id = ?").bind(allowanceMicros, id).run();
    return json({ id, allowanceMicros });
  }
  if (request.method === "POST" && url.pathname === "/admin/tokens") {
    const { account, label } = (await request.json()) as { account: string; label: string };
    return json({ token: await newToken(env, account, label), account, label });
  }
  if (request.method === "POST" && url.pathname === "/admin/grant") {
    const { account, micros, ref } = (await request.json()) as { account: string; micros: number; ref: string };
    await env.DB.prepare("INSERT OR IGNORE INTO ledger (account, period, kind, micros, ref, time) VALUES (?, ?, 'grant', ?, ?, ?)")
      .bind(account, await period(env, account), micros, ref, now).run();
    return json({ account, micros, ref });
  }
  if (request.method === "GET" && url.pathname === "/admin/ledger") {
    // What a month cost, by model: to set beside the provider's invoice.
    const account = url.searchParams.get("account") ?? "";
    // "2026-10": the calendar month, and the subscribers' months that began in it.
    const month = url.searchParams.get("period") ?? now.slice(0, 7);
    const rows = await env.DB.prepare(
      "SELECT model, kind, COUNT(*) AS requests, SUM(micros) AS micros, SUM(tokens_in) AS tokens_in, SUM(tokens_out) AS tokens_out, SUM(tokens_cached) AS tokens_cached, SUM(searches) AS searches FROM ledger WHERE account = ? AND period LIKE ? GROUP BY model, kind",
    ).bind(account, month + "%").all();
    return json({ account, period: month, rows: rows.results, allowance: await allowance(env, account) });
  }
  if (request.method === "POST" && url.pathname === "/admin/revoke") {
    // Every token of an account, or the one made at a moment: a stolen token stops at once.
    const { account } = (await request.json()) as { account: string };
    const done = await env.DB.prepare("UPDATE tokens SET revoked = 1 WHERE account = ?").bind(account).run();
    return json({ account, revoked: done.meta.changes });
  }
  if (request.method === "GET" && url.pathname === "/admin/report") {
    // A month in all: what the AI cost, what was topped up, how many subscribers — beside the invoices.
    const month = url.searchParams.get("period") ?? now.slice(0, 7);
    const spent = await env.DB.prepare(
      "SELECT model, COUNT(*) AS requests, SUM(micros) AS micros FROM ledger WHERE kind IN ('spend', 'spend_extra') AND substr(time, 1, 7) = ? GROUP BY model",
    ).bind(month).all();
    const sold = await env.DB.prepare(
      "SELECT kind, COUNT(*) AS count, SUM(micros) AS micros FROM ledger WHERE kind IN ('topup', 'refund', 'grant') AND substr(time, 1, 7) = ? GROUP BY kind",
    ).bind(month).all();
    const subscribers = await env.DB.prepare("SELECT COUNT(*) AS n FROM accounts WHERE kind = 'apple' AND expires > ?").bind(now).first<{ n: number }>();
    return json({ period: month, spent: spent.results, sold: sold.results, subscribers: subscribers?.n ?? 0 });
  }
  return json({ error: "not_found" }, 404);
}
