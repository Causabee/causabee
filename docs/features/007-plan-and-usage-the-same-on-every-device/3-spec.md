# F007 · Plan and usage, the same on every device — How

## Data

Nothing new is stored in the model. What is shown comes from what is there today:

- **What is bought:** `Store.plan`, `Store.renewal` (renews, ends, payment problem), `Store.bought` and the profile's `plan` / `planUntil`.
- **When Pro ended:** the newest Pro transaction's `expirationDate` in StoreKit's history (`Transaction.all`), on a device that bought it; elsewhere the profile's `planUntil` once it is past. Shown only while top-ups are left.
- **What is left:** `ProMeter` (F006) from `BeeServer`'s `monthUsed`, `extraShare`, `renewsOn`, `kind`.
- **Not counted yet:** Pro bought or a top-up known (`BeeServer.hasCredit`), and the beeserver has said nothing yet (`monthUsed` and `extraShare` unknown).
- **The switch:** `AutoMode` (`mail.auto`), synced through the profile's `autoOn` as today. Only its words change.

A new type in MatterCore, `PlanWords`, turns these into every word the row, the page and the switch say — the plan's name and corner, the row's line, the switch's words (on, off, waiting until a date), and whether the bars are in use — so each case of the wireframes is tested without a screen. `ProMeter` gains `inUse`: off, its bars are drawn greyed and their words end "· not in use"; and an empty bar for "not counted yet".

Schema change: none

## Sync and other devices

The switch syncs as today; the plan's words follow what each device knows. A device on an older build shows the plan card at the top of Settings and "Pro on" as today; its switch and this one's are the same setting.

## Privacy

Nothing new leaves the device.

## The AI

No AI involved.

## Calendar and Reminders

Not touched.

## When it fails

- The beeserver not reached: the bars as it said last; never said: the empty bar "not counted yet" (AC-3).
- StoreKit's history unavailable (a Mac that never bought, no profile date): the corner says "Free" or "Plus", not when Pro ended.
- A purchase that fails or waits: as today, its words on the page.

## Where in the code

- `Sources/MatterCore/Model/PlanWords.swift` (new): the words of every case; `ProMeter` (`ProMeter.swift`): `inUse`, and the uncounted bar.
- `Sources/Causabee/PlanSheet.swift`: `PlanSettings` splits into `PlanRow` — the one row with its line and thin bar — and `PlanPage`, the page: the card, the bars, the top-up button (with Free too), Change plan, Manage subscription, Restore, and "Use Pro" with its words.
- `Sources/CausabeePhone/SettingsSheet.swift`: the row and "Use Pro" at the top, the row opening `PlanPage` in the navigation stack.
- `Sources/Causabee/ModelChoice.swift`: the Mac's `Settings` window becomes panes — "General" (today's form without the plan) and "Plan" (`PlanPage`) — with a `TabView`.
- `Sources/Causabee/Store.swift`: when Pro ended, from StoreKit's history.
- `Sources/Causabee/Components.swift`, `Sources/CausabeePhone/Parts.swift`, `Sources/Causabee/ChatAdding.swift`, `Sources/Causabee/ModelChoice.swift` (`asksBeforeAuto`), `Sources/MatterCore/Model/DeviceTask.swift`: "Turn on Pro", "Turn off Pro", "Start Pro", "Turn on Pro?" become "Use Pro", "Stop using Pro", "Use Pro", "Use Pro?".
- Shared: `PlanRow`, `PlanPage`, `PlanWords` on every device; per device only where the row sits — a navigation row on the iPhone and the iPad, a pane on the Mac.
- Tests: `Tests/MatterCoreTests/PlanWordsTests.swift`, tagged `F007 AC-n`; the screen tests find Settings' sections by their ids.
