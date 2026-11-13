# F009 · Causabee in German

- Stage: 5
- Lane: feature
- Started: 2026-11-13
- Branch: feature/009-causabee-in-german

## Gates

| Stage | Opened | The owner's word |
|---|---|---|
| 1 · Why | 2026-11-13 | Yes, go |
| 2 · What | 2026-11-13 | open |
| 3 · How | 2026-11-13 | Approved, go |
| 4 · Looks | 2026-11-13 | Approved |

## Changes after a gate

- 2026-11-13, at Build: AC-9 says a test that asserts a formatted day now pins the language it asks about. AC-3 makes a day follow the device, and this Mac is English with a German region, so `ProMeter.long`, `NextStep.short` and the plan's corner give "1. December" and "30. Sep" here. Nine assertions in `ProMeterTests`, `PlanWordsTests` and `NextStepTests` were asserting the Mac's region without knowing it. The words themselves do not change.

<!-- A criterion or the spec changed after it was approved: the date, what changed, why. One line each. -->
