# F006 · The top-up in the bar — How

## Data

Nothing new is stored. The bars are drawn from what the beeserver already says of the account (`GET /v1/allowance` and every answer's own, read by `BeeServer.take`):

- `monthUsed` — 0…1 of this month's Pro;
- `extraShare` — what is left of top-ups, in Pro months (one top-up 0.333, two 0.667, four 1.333);
- `renewsOn` — the day the month starts anew;
- `kind` — `apple` (Pro bought), `credit` (top-ups only), `hand`.

A new type in MatterCore, `ProMeter`, turns these into what is shown, so it is tested without a screen:

- `bars`: the month's bar (left = 1 − `monthUsed`), when Pro is bought; the top-ups' bar (left = `extraShare`), when it is above 0. Each: what is left on the month's scale, the length (at most full), the number ("40 %", "133 %"), its words, whether it is in the warning colour, and what VoiceOver reads.
- `line`: "Starts anew on 1 December", and "· top-ups carry over" while a top-up is left. Today's "33 % of it from top-ups" goes: the second bar says it.
- `note`: today's notes, as they are ("Used for this month …", "Used. Apple's model …").
- Low: the month's and the top-ups' left together at most `BeeServer.lowShare` (0.2), as today. Then the bar now being used — the month's while any is left, else the top-ups' — is in the warning colour; the other keeps its own.

Schema change: none

## Sync and other devices

Nothing syncs: each device asks the beeserver itself, as today, and draws the same bars from the same answer. A device on an older build shows its one bar, as today; nothing it reads or writes changes.

## Privacy

Nothing new leaves the device. The app is still told shares, never money; the beeserver is not changed.

## The AI

No AI involved.

## Calendar and Reminders

Not touched.

## When it fails

- The beeserver cannot be reached: the bars show what it said last, as the one bar does today; with nothing ever said, no bar, as today, and the plan's words without it.
- An older beeserver without `extraShare`: no second bar (0), the month's bar as today.
- `extraShare` above one Pro month: the bar full, the number above 100 % (AC-4).

## Where in the code

- `Sources/MatterCore/Model/ProMeter.swift` (new): `ProMeter`, its bars, line, note and low — shared by every device.
- `Sources/Causabee/BeeServer.swift`: `ProBar` draws `ProMeter`'s bars, one under the other; `meterLine` and `runsLow` move into `ProMeter`, `runsLow` read from it where it is used today.
- `Sources/Causabee/Theme.swift`: the top-ups' colour, as Looks names it.
- `Sources/Causabee/PlanSheet.swift`: `PlanShot` gets a picture with a top-up left, for the screen tests and the website.
- Shared: `ProBar` and `PlanSettings` are the same view on the Mac, the iPhone and the iPad; nothing per device.
- Tests: `Tests/MatterCoreTests/ProMeterTests.swift`, tagged `F006 AC-n`.
