# F007 · Plan and usage, the same on every device — Proof

## Each criterion

| Criterion | Test | Result |
|---|---|---|
| AC-1 | `PlanWordsTests` "F007 AC-1 · One row says the plan in one line" — every line, the row before Mail on the iPhone and the iPad, the Mac's two panes. Seen in the iPhone simulator: the row and "Use Pro" on top, Mail in view; the owner on the Mac, 12 November | pass |
| AC-2 | "F007 AC-2 · The page's name and corner say what is bought"; seen in the simulator: "Causabee · Free", "Pro ended 7 November" | pass |
| AC-3 | "F007 AC-3 · Pro or top-ups: a bar, empty until counted" | pass |
| AC-4 | "F007 AC-4 · Off keeps the plan and greys the bars"; seen in the simulator: "… · not in use", the bar grey, and gold or yellow again when on | pass |
| AC-5 | "F007 AC-5 · Nothing to use: the switch leads to the plans"; seen: "Needs Pro or a top-up." | pass |
| AC-6 | "F007 AC-6 · A top-up from the page, whatever the plan"; seen: "Pro, now and then · $2.99" with Free and top-ups | pass |
| AC-7 | "F007 AC-7 · Used up or ended, the switch waits and nothing is sent" | pass |
| AC-8 | "F007 AC-8 · The same words wherever Pro is used or stopped" | pass |
| AC-9 | "F007 AC-9 · A top-up bought is used, and ends the wait" | pass |
| AC-10 | "F007 AC-10 · The same words on every device" | pass |

## Everything else still works

- **Unit tests:** 678 in 142 suites pass, 12 November, after the last change of code.
- **The screen tests,** 12 November, on the build the owner tried: iPhone 18 Pro 87 (7 skipped as made, none failed), iPad Air 5 of 5, Mac 33 of 33 — and again for TestFlight 247, the same.
- **The server:** not changed. **The schema:** untouched.
- **The UI check:** `ui-check.md`, "Verdict: pass".
- **Found while building, in the simulator:** Free showed "not counted yet" — an account counted as made by hand before the beeserver had answered; and the switch could not be turned on with a top-up the server had counted but not stored — both fixed before the screen tests.
- **Not pictured:** the Mac's Settings panes — a window picture brings up macOS's screen-recording dialog; the Mac's screen tests and the owner's try cover them.

## The AI's answers

No AI involved.

## The owner's own try

- **Mac,** "Causabee 0.5 Beta 134" (202611121635, signed, not notarized, never published), 12 November: "usage on mac is counted an looks like expected".
- **iPhone and iPad:** TestFlight 247, uploaded 12 November — not yet tried when this was written.
