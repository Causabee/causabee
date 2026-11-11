# F005 · The chat in two depths — Build

## Steps

On the branch `feature/005-the-chat-in-two-depths`.

1. **The tests, failing:** `ChatDepthTests` (MatterCore), tagged `F005 AC-n`; `AIJobTests` and the server's `jobs.test.ts` with the two new jobs.
2. **The light text:** `FactSheet.facts` builds it beside the deep text, from the same pass, with the same ids; `Facts.light`; none for several matters, a pinned item, or a matter where light saves less than half.
3. **The depth:** `ChatDepth.pick` — follow-up, words only the deep text has, the search words.
4. **The deeper ask:** `AssistantAsk.ask` with a depth; a light answer with `not_in_facts`, or citing an id the light text does not show, asks again deep, once; `Step.lookingDeeper`; the answer says its depth and whether it went deeper.
5. **The jobs:** `chat-light` and `chat-deeper` in `AIJob` and `jobs.json`, on Sol.
6. **The apps:** Mac `Conversation`, iPhone and iPad `AssistantSheet` — pick, pass, keep the depth in the turn for the follow-up; `AskSteps` says "Looking in the whole matter …".
7. **The pressure test:** `matter-spike pressure` with `--depths`: each case as today and with two depths, on the full demo matter (all demo matters merged in a copy of the simulator's demo store); cases and results in `tests/`. Then the light questions on Terra. The answers that differ read blind by Claude Fable 5.2, both orders.
8. **Everything else:** `scripts/test.sh`, the server's tests, the screen tests on iPhone, iPad and Mac, `/ui-check 5`. Deploy order for the owner: the server, then the apps.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | "F005 AC-1 · The light text holds what a quick question needs, with the same ids"; "F005 AC-1 · A full matter's light text is at most half"; the pressure test's tokens | unit, report |
| AC-2 | "F005 AC-2 · A question that needs the whole matter goes deep" | unit |
| AC-3 | "F005 AC-3 · A light answer that lacks something is asked again deep, and only that answer is shown" | unit (stubbed server) |
| AC-4 | "F005 AC-4 · An element only the whole matter holds sends the question deep"; `ChatControlTests` | unit |
| AC-5 | "F005 AC-5 · A follow-up never goes lighter" | unit |
| AC-6 | "F005 AC-6 · The depth depends on the question and the matter alone" | unit |
| AC-7 | `matter-spike pressure --depths` report in `tests/`, against the bar; the blind reading where answers differ by Claude Fable 5.2, the owner's choice (`tests/judge.py`) | report, judge |
| AC-8 | "F005 AC-8 · The chat's three jobs, the app's and the server's"; server "F005 AC-8 · The ledger tells light from deep" | unit |

## The UI check

`/ui-check 5` on `AskSteps` and the two chats after the code: `ui-check.md` here, "Verdict: pass" before the gate.

## What it adds to the manifesto

Section 5, the chat: *A quick question is answered from what it needs. "Not there" only after the whole matter* — with the tests of AC-3 and AC-4.

## The line for the release notes

A quick question in the chat costs a fraction: the bee sends what it needs, and looks in the whole matter when it must.
