# F004 · The right model for each job — How

## Data

**The jobs and their models: one table, `server/beeserver/src/jobs.json`.**

| Job | Id | What may wait | Model today | Model to test |
|---|---|---|---|---|
| Reading what comes in | `read` | yes | gpt-6.1-sol | gpt-6-luna, then gpt-6.1-terra |
| A digest of one mail or file | `digest` | yes | gpt-6.1-sol | gpt-6-luna, then gpt-6.1-terra |
| The brief, summary and next step | `brief` | yes | gpt-6.1-sol | gpt-6.1-terra |
| The chat | `chat` | no | gpt-6.1-sol | — (stays) |

- Each row: the job, its model, and whether it goes on Flex. A job's model changes in this file only, and only after its test (AC-3).
- The server imports it. The app has the same table as `AIJob` in `Sources/MatterCore/AIJob.swift`, for the own-key path and for naming the model; a unit test reads `jobs.json` and fails if the two differ.

**The ledger** (Cloudflare D1, `beeserver`): one column more, `job TEXT`, NULL for rows from before. Migration `server/beeserver/migrations/0004-job.sql`.

Schema change: none — SwiftData's schema is not touched; the ledger is the server's own database.

## Sync and other devices

Not touched. Every device sends the same job for the same work, and the server picks the model by the job, so the Mac, the iPad and the iPhone use one model per job (principle 12). An older build sends no job: its request is passed on as it asks, with its model, and counted as job `unknown` (AC-1).

## Privacy

Unchanged: every job sends only the disguised text it sends today, to OpenAI, through the beeserver. The job's name is one word in a request header (`causabee-job`), sent to our own server, not to OpenAI. The quality tests send only the demo's invented matters; never real mail (the golden set stays on this Mac).

## The AI

**Which model answers.** The app sends the job; the beeserver sets the model from `jobs.json` and refuses another one for that job (AC-2). The answer says which model wrote it, and the app names that one, not the one it asked for (AC-6).

**Flex** (AC-4), on the server, for the jobs marked so: the request goes with `service_tier: "flex"`; on a 429 "resource unavailable" — not charged — it goes once more without it, at the normal tier. The cost in the ledger is the tier OpenAI says it used (`service_tier` in the answer); `prices.ts` gets Flex's prices (half) and the cache-write price of GPT-5.6 and later (1.25× the input, 30 minutes).

**The cache** (AC-5):
- Each prompt's `system` is the job's fixed rules; the schema goes with it, unchanged between requests.
- Each `user` part puts what changes least first (the owner's names, the matters known) and the one new thing last.
- The server sets `prompt_cache_key` to a hash of the account, so one person's requests share their cache.
- Where a job's fixed part is under 1,024 tokens it is not cached at all; the spec's test lists each job's fixed length, and the build looks at whether a job is better off as one prompt with its fellow jobs' rules or alone.

**The quality tests** (AC-3): `matter-spike jobs`, a new command, runs each job on the demo's invented matters — the demo's mails, files and screenshots for `read` and `digest`, its matters for `brief` — once on Sol and once on the model to test, with the same disguise and the same prompts the app sends. It writes the answers and a comparison:

- `read`: per item, the matter each model chose, the tasks and dates each found, and which the other did not; the share against AC-3's bar.
- `digest`: the facts of each, side by side.
- `brief`: both briefs, summaries and next steps for each matter, in a random order as A and B, for the owner to judge blind; the key kept apart.

Results and answers are kept in `docs/features/004-the-right-model-for-each-job/tests/`.

## Calendar and Reminders

Not touched.

## When it fails

| What fails | What the user sees |
|---|---|
| Flex is busy | Nothing: the server asks again at the normal tier; the answer only comes a little later |
| Flex is slow beyond the server's wait | The server gives up Flex after 60 s and asks at the normal tier |
| The cheaper model's answer does not fit the schema | As today: the app's error for an unreadable answer, and the item waits to be read again. The test (AC-3) is what keeps this from happening often; a job that fails it does not move |
| An older build asks without a job | It is answered as today, with Sol, and counted as `unknown` |
| The table in the app and on the server differ | The unit test fails before a build can go out |
| The migration is not applied | The server's insert fails and it says so in its log; the request is still answered and charged — the deploy waits for the migration, written in the README |

## Where in the code

**The server** (`server/beeserver`):
- `src/jobs.json`: the table.
- `src/index.ts` `relay()`: reads `causabee-job`; picks the model from the table, or refuses (`model_not_offered`); Flex and its one retry; `prompt_cache_key`; writes `job` into the ledger; a report per job beside the one per model.
- `src/prices.ts`: Flex prices, cache-write price.
- `migrations/0004-job.sql`, and `schema.sql` with the column.
- `test/`: vitest for the table, Flex's retry, the job in the ledger, the refusal.

**The app** (`Sources/MatterCore`, shared by Mac, iPad and iPhone):
- `AIJob.swift`: the table, as Swift.
- `Claude.swift` `send(_:model:)` takes the job and sends it as `causabee-job`; on the own-key path it uses the job's model.
- The callers say their job: `Extractor` (read), `Digests` (digest), `AdviserPrompt` (brief), `Assistant` (chat; its next-step and summary calls are brief).
- The prompts in `Prompts/` and the `user` parts put what stays the same first.
- What names the model shows the model of the answer (`Claude.Model.serving`), with `Claude.Model.known` holding Terra and Luna too.

**The test tool:** `Sources/MatterSpike` gets `jobs`.

**Tests**, tagged `F004 AC-n`:

| Criterion | Test |
|---|---|
| AC-1 | server: a request with a job writes it; without one, `unknown`; the per-job report sums right. App: every caller sends a job |
| AC-2 | server: a model the table does not give the job is refused. App: `AIJob` equals `jobs.json` |
| AC-3 | `matter-spike jobs` reports, kept with the feature; the owner's blind judgement for `brief` |
| AC-4 | server: a waiting job goes on Flex; a 429 "resource unavailable" is asked again at the normal tier; the chat never goes on Flex; the cost follows the tier used |
| AC-5 | app: each job's prompt starts with its fixed part, the same bytes for two different items; the ledger's cached share per job, a week after release |
| AC-6 | app: the label shown is the answering model's; `SaidAsItIsTests` on the website's words |

**Deploying:** the server change goes out before any app build that sends jobs, and the migration before the server. Both are run by the owner (`npm run deploy`, the D1 console), as before.
