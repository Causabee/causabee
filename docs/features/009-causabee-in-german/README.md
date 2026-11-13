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
- 2026-11-13, at Build: the welcome's three pictures are the app's own screens, so on a German device they showed English ones. They are now a resource like any other word: `App/Resources/en.lproj` holds the English six (`welcome-1…3.png`, `phone-welcome-1…3.jpg`), `App/Resources/de.lproj` the German six, taken from the German example matter. No code changed — Apple's own lookup takes the device's language, which is why the English ones had to move out of the bundle's root first. Not in a criterion: AC-1 is about words. The owner asked for German shots on 13 November, and a German welcome showing English screens is what principle 10 calls squeezing.
