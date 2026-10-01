# Concept: the credits server

This belongs to [credits-plan.md](credits-plan.md) and explains Step 1 there in detail.
Written 2026-10-01. Nothing here is built yet.

## 1. How to reach the AI: direct, through a gateway, or through a cloud

| | **Direct** (today) | **Gateway** (e.g. OpenRouter) | **Big cloud** (AWS Bedrock, Google Vertex, Azure) |
|---|---|---|---|
| Accounts and bills | One per provider (Anthropic, Mistral, OpenAI) | One | One |
| Price | The list price | List price, plus about 5% on every top-up | About the list price |
| Features | All of them: prompt cache, Opus fallback, `effort`, strict JSON | Some don't come through, or come later | Some come later, and some never |
| Who sees the disguised text | The provider | The gateway **and** the provider | The cloud (which also runs the model) |
| Data in the EU | Mistral yes, the others US | Mostly US | Yes, EU regions can be chosen |
| Work for Matterbee | None: `Claude.swift` already speaks all three | Rewrite the request shapes | Rewrite, plus the cloud's login and setup |

**Recommendation: stay direct.**

- The app already speaks all three APIs, including the features that keep the cost down (the
  prompt cache, Opus's fallback).
- A gateway adds one more company that sees the text, and about 5% on top. That buys you one
  bill instead of two or three, which isn't worth it at this size.
- A big cloud is only worth it if "everything stays in the EU" becomes a selling point. Keep it
  in mind for later.

**In credits mode, three choices:**

- **Quick: Mistral Large 3.** About 1 credit a mail. Cheap, and from an EU company, which is a
  good privacy story.
- **Careful: OpenAI GPT-6.1 Sol.** About 4 credits a mail. It is cheap and very good, so it is
  the default.
- **Best: Claude Opus 5.** About 7 credits a mail.

That means three accounts, three bills and three data processing agreements. The app already
speaks all three, so it adds no work in the code.

**In each provider's console, before the first paying user:**

- Turn on spending limits and alerts. Example: stop at $100 a month.
- Check that API data isn't used for training, and turn it off where it is a setting.
- Use a key just for the server, never the one you use yourself.

## 2. The server

```
                       ┌──────────────── Cloudflare ────────────────┐
 iPhone / Mac app ───▶ │  Worker "matterbee-credits" (TypeScript)    │ ───▶ api.anthropic.com
   session token       │   · checks the token and the balance        │ ───▶ api.mistral.ai
                       │   · adds the provider key                   │ ───▶ api.openai.com
                       │   · reads `usage`, takes off credits        │
                       │                                             │
                       │  D1 database (SQLite, kept in the EU)       │
                       │   accounts · devices · ledger               │
                       │                                             │
                       │  Secrets: provider keys, signing key,       │
                       │           Apple keys                        │
                       └─────────────────────────────────────────────┘
 Apple ──(refund notices)──▶ Worker
```

### Why Cloudflare Workers

- **No machine to look after:** no updates, no disk, no backups of a server.
- **Cost:** the paid plan is $5 a month. Take it, not the free plan. The free plan gives very
  little CPU time to each request, and has a daily limit on requests.
- Waiting for the AI's answer doesn't count as CPU time, so a job that takes minutes is fine.
  (The app waits up to 10 minutes.)
- D1 can be kept in the EU.

The other choice would be a small Swift server (Vapor) on a rented machine. It is nice
because it's the same language, but it is a machine you have to keep updated. That isn't
worth it for this.

### The routes

| Route | What it does |
|---|---|
| `POST /v1/session` | The app sends Apple's signed `AppTransaction` and a DeviceCheck token. It gets back a session token that lasts 1 hour, and the account's balance. A new account gets the 200 free credits here, once. |
| `POST /v1/ai/anthropic` | The same body the app sends to Anthropic today. The answer comes back unchanged, plus a header `matterbee-credits-left`. |
| `POST /v1/ai/mistral` | The same, for Mistral. |
| `POST /v1/ai/openai` | The same, for OpenAI (the Responses API). |
| `GET /v1/balance` | The balance, and the last 20 rows of the ledger, for Settings. |
| `GET /v1/prices` | Credits per million tokens for each model. The app's quotes use the same numbers as the server. |
| `POST /v1/purchase` | The app sends the signed transaction from StoreKit. The server checks it and adds the credits once. |
| `POST /apple/notifications` | Apple reports refunds here. The server takes the credits back. |
| `POST /admin/grant` | Only you, with your own secret. Gives credits by hand, for Step 1 and for support. |

### The database: three tables

```
accounts  id (from AppTransaction) · created · trial_given · blocked
devices   device_hash · account · trial_given        ← one trial per device
ledger    id · account · kind (trial | purchase | spend | refund | grant)
          · credits (+/-) · ref (unique: transaction id or request id)
          · model · tokens_in · tokens_out · time
```

- **The balance is the sum of the ledger.** Nothing else holds money, so everything can be
  checked.
- `ref` is unique, so one purchase or one refund can never count twice.
- **Never stored:** questions, answers, mail text, names. Workers logging stays off for the
  request body.

### One AI request, step by step

1. The app sends the request with its session token.
2. The Worker checks the token. Is the account blocked? Is the balance at least 20 credits?
   If not, it answers `402 No credits` and the app shows "Buy credits".
3. The Worker adds the provider key and passes the body on unchanged.
4. The answer comes. The Worker reads `usage` (input, output, cache write, cache read) and
   works out the cost exactly like `Claude.Model.cost(...)`. The prices are kept in one table
   on the server.
5. It writes one `spend` row to the ledger and sends the answer back with the new balance.

There is no "hold" before the request. Instead, a balance may go a little below zero once
(at most one request). That is simpler, and at a few cents the loss is small.

**Limits against bugs and abuse:**

- At most 1,000 credits a day per account.
- At most 5 requests at the same time per account.
- `max_tokens` is capped on the server, so one request can't run away.

### Apple's side

- **Signed transactions and `AppTransaction`:** Apple signs them (JWS). The Worker checks the
  signature with Apple's public certificates. Apple's *App Store Server Library* does this. If
  it doesn't run on Workers, about 50 lines of Web Crypto do the same.
- **DeviceCheck:** two bits per device that Apple keeps for you. Bit 1 = "trial given". Even
  after a reinstall or with a second Apple Account, the device gets no second trial.
- **Refunds:** set the URL `https://<server>/apple/notifications` in App Store Connect
  (*App Store Server Notifications, version 2*).

## 3. What changes in the app

- `Claude` (`Sources/MatterCore/Claude.swift`) gets a second way to send. In credits mode the
  base address is the server, and the header is `authorization: Bearer <session token>`
  instead of `x-api-key`. Today only Anthropic's address can be changed (`endpoint`). Mistral's
  and OpenAI's are written into the code, so they become changeable too.
- `ModelChoice.client(for:)` gives a credits client when "Pay with: Matterbee credits" is on,
  and today's key client otherwise.
- A small `CreditsAccount` keeps the session token in the Keychain, gets a new one when it runs
  out, and holds the balance for the screen.
- Quotes ask `GET /v1/prices` once a day and show credits instead of dollars.

## 4. What it costs to run

| | per month |
|---|---|
| Cloudflare Workers, paid plan | $5 |
| D1 database | included at this size |
| Domain (e.g. `api.matterbee.app`) | about €1 |
| **Together** | **about €6** |

Each €4.99 pack leaves about €1.25 after the AI cost (see the plan). So **about 5 packs a
month** cover the server. Until then, you pay the difference, about what you spend on the API
today.

## 5. Order of work

1. Create the Worker and D1, put your keys in its secrets, add `/admin/grant` and the two AI
   routes. Leave out Apple for now.
2. A hidden switch in the app (debug only): "use the credits server". You use it for a month.
   **The check:** the server's ledger matches the providers' invoices within a few percent.
3. Add `/v1/session` with `AppTransaction`, then the trial with DeviceCheck.
4. `/v1/purchase` and the refund notices, tested with TestFlight's sandbox money.
5. Only then does credits mode become the default for new users.
