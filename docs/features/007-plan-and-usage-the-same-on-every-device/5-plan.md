# F007 · Plan and usage, the same on every device — Build

## Steps

On the branch `feature/007-plan-and-usage-the-same-on-every-device`.

1. **The tests, failing:** `PlanWordsTests` (MatterCore), tagged `F007 AC-n`.
2. **The words and the wait:** `PlanWords` — the plan's name, corner, the row's line, the switch's line; `ProMeter` with `inUse` and `counted`; `ProWait`, what the switch waits for after the month runs out or Pro ends.
3. **The switch waits:** `AutoMode.isOn` false while `ProWait` holds; `BeeServer.proStopped` sets it instead of turning the switch off; a top-up, the date, or something left ends it.
4. **The views:** `PlanSettings` becomes the plan page, its words from `PlanWords`, the top-up with Free too, "Use Pro"; `PlanUsageRows` at the top of the iPhone's and iPad's Settings; the Mac's Settings window in two panes, General and Plan. When Pro ended, from StoreKit's history (`Store.proEnded`).
5. **The words elsewhere:** the bees' menus and read-aloud values, the chat's offer, the question asked first, the device's answer, the messages when the month runs out or Pro ends.
6. **Everything else:** `scripts/test.sh`, the server's tests, the screen tests on iPhone, iPad and Mac, `/ui-check 7`, pictures from the simulator and the Mac.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | "F007 AC-1 · One row says the plan in one line"; the screen tests open Settings on three devices | unit, screen |
| AC-2 | "F007 AC-2 · The page's name and corner say what is bought" | unit |
| AC-3 | "F007 AC-3 · Pro or top-ups: a bar, empty until counted" | unit |
| AC-4 | "F007 AC-4 · Off keeps the plan and greys the bars" | unit |
| AC-5 | "F007 AC-5 · Nothing to use: the switch leads to the plans" | unit |
| AC-6 | "F007 AC-6 · A top-up from the page, whatever the plan" (the source's words) | unit |
| AC-7 | "F007 AC-7 · Used up or ended, the switch waits and nothing is sent" | unit |
| AC-8 | "F007 AC-8 · The same words wherever Pro is used or stopped" (the sources' words) | unit |
| AC-9 | "F007 AC-9 · A top-up bought is used, and ends the wait" | unit |
| AC-10 | "F007 AC-10 · The same words on every device" (one `PlanWords` for all) | unit |

## The UI check

`/ui-check 7` on `PlanSheet`, `SettingsSheet`, `ModelChoice` and the bees after the code: `ui-check.md` here, "Verdict: pass" before the gate.

## What it adds to the manifesto

A rule, with its test: **What you have and whether you use it are two things.** Pro and top-ups are bought; "Use Pro" decides whether they are used now. Turning it off takes nothing away; running out does not turn it off — it waits. Tested by "F007 AC-4" and "F007 AC-7".

## The line for the release notes

Settings opens with your own settings: your plan is one row, its page says what you have, and "Use Pro" decides whether it is used — off takes nothing away.
