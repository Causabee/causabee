# beeserver

Causabee Pro's way to the bigger AI, at `beeserver.causabee.app` — the plan is in
`concept/pro-service.md`. A Cloudflare Worker with a D1 database. The app sends the same request it
sends a provider today; the server checks who asks and whether this month's Pro has room, adds
Causabee's own key, passes the request on unchanged, and writes what it cost into the ledger.
The text is disguised already, and none of it is stored or logged.

This is step 1: accounts and tokens are made by hand, for Ralf's own use. Apple's signed
subscriptions, the notifications and the Mac's device grant come next.

## Routes

| Route | |
|---|---|
| `POST /v1/ai/openai` | OpenAI's Responses API body, as the app sends it today |
| `POST /v1/ai/anthropic` | Anthropic's Messages API body; `anthropic-version` and `anthropic-beta` passed on |
| `GET /v1/allowance` | `{ monthUsed: 0…1, renewsOn, extra }` — a share, never money |
| `POST /admin/accounts` | `{ id, allowanceMicros }` — $4.50 is `4500000` |
| `POST /admin/tokens` | `{ account, label }` — the token is shown this once |
| `POST /admin/grant` | `{ account, micros, ref }` — a top-up by hand |
| `GET /admin/ledger?account=&period=2026-10` | a month by model, to set beside the provider's invoice |

Answers carry `causabee-month-used` and `causabee-renews-on`. Errors: `401` unknown token,
`400 model_not_offered`, `402 allowance_used` (the app falls back to Apple's models), `429 daily_limit`.

## Run it here

```
npm install
npm run db:local
printf 'ADMIN_SECRET=...\nOPENAI_API_KEY=...\nANTHROPIC_API_KEY=...\n' > .dev.vars   # git ignores it
npm run dev
npm test
```

## Put it online, once

1. A Cloudflare account; Workers paid plan ($5 a month).
2. `npx wrangler login`
3. `npx wrangler d1 create beeserver --location=weur` → the id into `wrangler.toml`, then `npm run db:remote`
4. `npx wrangler secret put OPENAI_API_KEY` (a key made for the server alone, with a spending limit),
   the same for `ANTHROPIC_API_KEY` and `ADMIN_SECRET`
5. `npm run deploy`
6. `beeserver.causabee.app` as the Worker's custom domain (the domain's DNS must be on Cloudflare,
   or a CNAME to the Worker)
