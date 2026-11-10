# F004 · The right model for each job — Proof

## Each criterion

| Criterion | Test | Result |
|---|---|---|
| AC-1 | Server, `jobs.test.ts` "F004 AC-1 · A request's job is in the ledger": the job beside the model; an older build's request counted as `unknown` and answered with Sol; the request still counted when the migration is missing. App, `AIJobTests` "Every caller says its job" (all six sends) and "Through the beeserver, the request names its job and leaves the model to it". The report per job and day: `GET /admin/report` and the query in the server's README — not yet run against the live ledger | pass |
| AC-2 | Server "F004 AC-2 · A model the table does not give the job is refused": the job's model set, another refused and nothing sent on, an unknown job refused. App "F004 AC-2 · The app's table is the server's": model, effort and Flex of every job the same in `jobs.json` and `AIJob` | pass |
| AC-3 | `matter-spike jobs` on the demo's 93 invented items and 16 matters, `tests/results.md`: digests on Terra carry the same facts as Sol's; the brief on Terra judged blind by the owner, no worse; reading tried on Terra, Luna (twice) and Claude Haiku 5.5 — all below the bar, so reading stays on Sol; the chat stays on Sol. Every answer kept in `tests/answers/`. App "F004 AC-3 · A job is on a cheaper model only with its test kept": the table cannot move a job without its results in `tests/` | pass |
| AC-4 | Server "F004 AC-4 · What may wait goes on Flex, and once more without it when Flex is busy": reading, digests and the brief on Flex, never the chat; a 429 asked again at the normal tier and counted once; Flex counted at half the price. App "F004 AC-4 · What may wait is marked for Flex in the table, and only the server asks for it" | pass |
| AC-5 | App "F004 AC-5 · Each job's prompt starts with what stays the same": the same bytes up to the item's own part for two items; the instructions and schema the same for every request of a job. Server "The cache is counted as OpenAI charges it" and "keys the cache by the account, never by the text". The cached share per job in the ledger: measured a week after release, not yet | pass |
| AC-6 | App "F004 AC-6 · The model named is the model that answered" and "causabee.app names the model of each job, and no longer one AI when there are more"; `SaidAsItIsTests`. Seen in the demo on the Mac, the iPhone and the iPad: "Pro · GPT-6.1 Terra" under the next step, "OpenAI GPT-6.1 Sol" beside a chat answer (`proof/`) | pass |

The server's tests were written before the server's code and ran for the first time on 10 November, when Node was put on this Mac: 32 pass, 13 of them F004's.

## Everything else still works

- **Unit tests:** 635 in 136 suites pass, on 11 November, after the last change. One older test was changed on purpose: `OpenAITests` held that Sol is the only model known; it now holds that every model known is OpenAI's, on the one key.
- **The server:** 32 tests in 4 files pass; `tsc` finds nothing; the Worker bundles in a dry run. Nothing was deployed.
- **The schema:** SwiftData's models are untouched (`git diff main -- Sources/MatterCore/Model/Models.swift` is empty; `CloudKitSchemaTests` passes). The ledger, the server's own database, gets two columns — `job`, and `tier` beyond the spec's one, to see how often Flex was busy.
- **The screen tests,** on the demo, 10 and 11 November, after the last change:
  - iPhone 18 Pro: 86 tests, 79 pass, none fails; 7 skipped as made — the iPad's five, and two that run only when asked for.
  - iPad Air 11-inch: its 5 pass.
  - Mac: 33 clicked through, all pass.
- **causabee.app:** the new heading, sentence and chips looked at in the browser at desktop width and at 375: no overflow.
- **Not looked at on screen:** Settings' sentence on the Mac and the iPhone (its words are tested as text), and the line while what came in is sorted (it follows the reading model, Sol, and reads as before).
- **Changed beyond the spec, on the owner's word on the way:** the reading prompt says each item's language (the Luna test); reading thinks on "low" (the owner's yes: as good as Sol left to itself, 5 seconds an item for 9); the test tool can try another provider's model (the Haiku test) — the app cannot.
- **Parked on the way:** Sol's cached read counted at 0.1× where OpenAI charges 0.05×; a third party's private reason written into a task (the owner's finding, 10 November); reading on Claude Haiku 5.5 (tried in this feature after all: below the bar).

## The AI's answers

`tests/results.md`, on the demo's invented matters only; $4.17 in all on the owner's keys.

| Job | Tried on | Result |
|---|---|---|
| Reading what comes in | Terra | 7 of 93 items in another matter than Sol's, 85% of its tasks and dates: below the bar |
| | Luna | 2 in another matter; 56% — it wrote English items' tasks in German; with the language told, 80%: below the bar |
| | Claude Haiku 5.5 | 7 in another matter, 69%: below the bar |
| | Sol, effort low | 1 in another matter, about 95%; Sol run twice differs from itself by as much (3 items, 95.4%). 11% cheaper, 5 seconds an item for 9: taken |
| Digests | Terra, Luna | no number or date that Sol's does not have, in 78; Luna wrote one in German. Terra taken |
| The brief | Terra | 16 matters, A and B blind; the owner: "they both look correct to me … I don't see the big difference here." Terra taken |

## The owner's own try

- **10 November:** the owner read the 16 pairs of briefs blind and found neither worse; saw the results of each test as they came and decided each move; saw the demo's pictures on the Mac, the iPhone and the iPad.
- **Still the owner's:** the deploy — the migration `0004-job.sql`, then `npm run deploy`, then a build of the app — and a look at their own matters after it: a brief written by Terra, what came in sorted by Sol, the ledger's rows with their job and tier.
- **The measure of the Why** — a full day's cost at most half of $0.87, over a week of the owner's own use — can only be read from the ledger a week after the deploy.
