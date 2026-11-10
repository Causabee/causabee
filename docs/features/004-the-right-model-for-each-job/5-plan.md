# F004 · The right model for each job — Build

## Steps

On the branch `feature/004-the-right-model-for-each-job`.

1. **The tests, failing:** the server's (vitest) and the app's (`AIJobTests`), tagged `F004 AC-n`.
2. **The server:** `src/jobs.json` (every job on Sol to start); `relay()` reads `causabee-job`, checks the model against the table, sends waiting jobs on Flex and once more without it on "busy", sets `prompt_cache_key`, writes the job into the ledger; `prices.ts` with Flex and cache-write prices; `migrations/0004-job.sql`; a report per job.
3. **The app:** `AIJob` — the same table; `Claude.send(_:job:)` sends the job and asks the job's model; the callers say their job; the models Terra and Luna known and named; the prompts' fixed part first.
4. **The quality tests:** `matter-spike jobs` on a demo store — `read` and `digest` on Sol, Luna and Terra, `brief` on Sol and Terra — answers and comparisons into `tests/`, the briefs as A and B for the owner.
5. **The table** set from the results; the words of stage 4 with the models that passed; the demo's notes.
6. **Everything else:** `scripts/test.sh`, the server's tests, the screen tests on iPhone, iPad and Mac. The deploy order written down for the owner: the migration, the server, then the app.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | server "F004 AC-1 · A request's job is in the ledger"; app "F004 AC-1 · Every caller says its job" | unit |
| AC-2 | server "F004 AC-2 · A model the table does not give the job is refused"; app "F004 AC-2 · The app's table is the server's" | unit |
| AC-3 | `matter-spike jobs` reports in `tests/`, against the bar; the owner's blind judgement of the briefs | report, owner |
| AC-4 | server "F004 AC-4 · What may wait goes on Flex, and once more without it when Flex is busy" | unit |
| AC-5 | app "F004 AC-5 · Each job's prompt starts with what stays the same"; the ledger's cached share a week after release | unit, ledger |
| AC-6 | app "F004 AC-6 · The model named is the model that answered"; `SaidAsItIsTests` | unit |

## What it adds to the manifesto

Section 6, how we know she works: a job moves to a cheaper model only after it does its job as well as the model before, on the demo's matters; the test and its answers are kept.

## The line for the release notes

The bee costs less: each job uses the smallest OpenAI model that does it as well as GPT-6.1 Sol.
