# F007 · Plan and usage, the same on every device

- Stage: done
- Lane: feature
- Started: 2026-11-12
- Branch: feature/007-plan-and-usage-the-same-on-every-device

## Gates

| Stage | Opened | The owner's word |
|---|---|---|
| 1 · Why | 2026-11-12 | Yes, go |
| 2 · What | 2026-11-12 | Yes, go |
| 3 · How | 2026-11-12 | Yes, go |
| 4 · Looks | 2026-11-12 | Approved |
| 5 · Build | 2026-11-12 | Yes, both |
| 6 · Proof | 2026-11-12 | done |

## Changes after a gate

<!-- A criterion or the spec changed after it was approved: the date, what changed, why. One line each. -->
- 2026-11-12, the Looks: the row's thin bar is the one now in use — the month's while any is left, then the top-ups' — not the first. Why: on the owner's iPhone it showed only the month's, used up, while top-ups were in use. The owner: "on iphone the card in the settings doens show th top up bar, can be misleading." — "it should always show what using".
- 2026-11-12, the How: the switch is no longer turned off when Pro is used up or ended; it waits, and the device keeps until when (`pro.waitsUntil`). Why: AC-7, approved, says the switch stays on and waits — the How had missed that today it is turned off (`BeeServer.proStopped`). Found while writing the Looks. The owner: "Approved".
