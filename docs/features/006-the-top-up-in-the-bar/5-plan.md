# F006 · The top-up in the bar — Build

## Steps

On the branch `feature/006-the-top-up-in-the-bar`.

1. **The tests, failing:** `ProMeterTests` (MatterCore), tagged `F006 AC-n`.
2. **`ProMeter`** in `Sources/MatterCore/Model/ProMeter.swift`: the bars from `monthUsed`, `extraShare`, `kind` and `renewsOn`; their length on the month's scale, number, words and what VoiceOver reads; the line, the note, running low.
3. **The view:** `ProBar` draws `ProMeter`'s bars one under the other; `BeeServer.meterLine` goes, `runsLow` reads `ProMeter`. `Theme.topUp` in `Theme.swift` and its row in `docs/design-system/colors.md`.
4. **AC-9:** the top-up's button and choice with Pro say "Add a top-up", in `PlanSheet`.
5. **A picture:** `PlanShot` with a top-up left, for the screen tests and the website; looked at on the Mac, the iPhone and the iPad.
6. **Everything else:** `scripts/test.sh`, the server's tests, the screen tests on iPhone, iPad and Mac, `/ui-check 6`.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | "F006 AC-1 · Pro and a top-up: two bars, the month's alone and the top-ups'" | unit |
| AC-2 | "F006 AC-2 · The month is used first: the top-ups' bar waits" | unit |
| AC-3 | "F006 AC-3 · A new month: the month full again, the top-up where it was, and the line says it carries over" | unit |
| AC-4 | "F006 AC-4 · Top-ups add up on the month's scale, the number past 100 %" | unit |
| AC-5 | "F006 AC-5 · Top-ups alone: only their bar" | unit |
| AC-6 | "F006 AC-6 · No top-up left: the month's bar alone, its note as today" | unit |
| AC-7 | "F006 AC-7 · Running low: the bar in use turns, the other keeps its colour" | unit |
| AC-8 | "F006 AC-8 · VoiceOver reads each bar on its own" | unit |
| AC-9 | "F006 AC-9 · With Pro the top-up is added, not for this month" | unit (the source's words) |

## The UI check

`/ui-check 6` on `ProBar`, `PlanSettings` and `Theme` after the code: `ui-check.md` here, "Verdict: pass" before the gate.

## What it adds to the manifesto

Nothing: no rule of the bee's. The top-ups' colour goes into `docs/design-system/colors.md`.

## The line for the release notes

The plan shows a top-up in a bar of its own, under the month's: it carries over to the next month until it is used.
