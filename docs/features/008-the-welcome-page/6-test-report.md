# F008 · The welcome page — Proof

## Each criterion

Every row ran on 13 November 2026, on this Mac (`swift test`, `npx vitest run`) or in the simulator.

| Criterion | Test | Result |
|---|---|---|
| AC-1 · A few calm pages, then in | `WelcomeTests` "F008 AC-1 · A few calm pages, then in" | pass |
| AC-2 · Private, said once | "F008 AC-2 · Private, said once" | pass |
| AC-3 · The welcome ends at the first step | "F008 AC-3 · The welcome ends at the first step, in the person's own Causabee"; seen on the iPhone and the Mac | pass |
| AC-4 · Typed, it becomes the first matter | "F008 AC-4 · Typed, it becomes the first matter"; "· The first matter read by the best reader, told it is the first"; "· Nothing made up: a name and dates only from the line's own words"; "· Typed words show once: as the owner's note, never as a mail" | pass |
| AC-5 · Added, it becomes the first matter | "F008 AC-5 · Added, it becomes the first matter" | pass |
| AC-6 · The demo is the second way | "F008 AC-6 · The demo is the second way, never the first" | pass |
| AC-7 · Nothing asked at the door | "F008 AC-7 · Nothing asked at the door" | pass |
| AC-8 · Mail is offered once there is a matter | "F008 AC-8 · Mail is offered once there is a matter" | pass |
| AC-9 · Empty is the first step, everywhere | "F008 AC-9 · Empty is the first step, everywhere" | pass |
| AC-10 · Already in use elsewhere | "F008 AC-10 · Already in use elsewhere: straight to the matters" | pass |
| AC-11 · The same welcome on every device | "F008 AC-11 · The same welcome on every device" | pass |
| AC-12 · Your name, asked once | "F008 AC-12 · Your name, asked once, after the first matter"; seen on the Mac ("This is you: Ralf Chille?") and the iPhone | pass |
| AC-13 · Notifications asked later | "F008 AC-13 · Notifications asked later, not at the door" | pass |
| AC-14 · A start credit, given at the first start | `server/beeserver/test/start.test.ts` "F008 AC-14 · The start credit" (6 tests: once per Apple account, the App Store's day, TestFlight always and forgettable, no Xcode, not signed by Apple); `WelcomeTests` "F008 AC-14 · The start credit, asked for at the first start on every device"; the owner's own try below | pass |
| AC-15 · Said once, plainly | "F008 AC-15 · Said once, plainly, and named in Pro's use"; the line seen on the owner's second device | pass |
| AC-16 · It works as a top-up does, on every plan | "F008 AC-16 · It works as a top-up does, on every plan"; the beeserver's ledger shows the first read paid from the grant | pass |
| AC-17 · Used: back to the device, and a top-up offered | "F008 AC-17 · Used: back to the device, and a top-up offered once" | pass |

AC-17's card has not been seen on a device: it needs a credit used up, and the owner's has $1.49 of $1.50 left. Its rule and its place are held by the test.

## Everything else still works

- **Unit tests (`scripts/test.sh`, 13 November):** 704 tests in 145 suites, all pass. In an earlier run, while the simulator's tests were running beside them, the load-sensitive `SpeedTests` "What the screens work out, measured" failed; on a quiet Mac it passes.
- **The beeserver (`npx vitest run`):** 44 tests in 6 files, all pass; 6 of them new for the start credit.
- **Screen tests, the iPhone (`CausabeePhoneUITests`, iPhone 17e):** 87 tests, 7 skipped as designed, 0 failures.
- **Screen tests, the iPad (`PadTests`) and the iPhone again:** run by `scripts/testflight.sh` before TestFlight 250 and 251, both times green — nothing is uploaded otherwise.
- **The Mac's click-through tests (`scripts/mac-tests.sh`, 13 November):** 32 of 33 passed. One, `ManifestoMacTests` "every matter opens at its next step · Application", timed out while the iPhone's screen tests ran beside it; run again on its own it passes. The three chat-panel tests are expected failures, as before (the Mac's test runner cannot click the chat panel's pills).
- **The UI check (`/ui-check 8`):** 0 ✗, one radius kept on purpose. `ui-check.md` says "Verdict: pass", twice — 12 November and again on 13 November for the second round.

## The AI's answers

**Typed lines, read as a first start, 13 November.** Thirteen made-up lines: the ten of 12 November and three with typos, run with both readers (`WelcomePressureTests`, `CAUSABEE_PRESSURE=1`; the cloud reader with `CAUSABEE_PRESSURE_CLOUD=1`). Nothing of the owner's own was used.

- **Apple's model on this Mac (`device-2`):** every line became a matter. Names in the line's own words and language: "Umzug", "Moving to Lisbon", "Steuererklärung", "Hochzeit", "Bathroom renovation", "Science fair project", "Kita-Platz". The typo lines: "Muttis Reha" and "Steuererklrung" right; "Der umzug ist für dne 1.2.2027 geplant" gave no usable name, so the net in code made it the line before its date. Its date was right (1 February 2027).
- **Pro's reader, Sol (`extract-v18`):** every line became a matter, each name in the line's own language, the typo lines included — "Umzug" from "Der umzug ist für dne", "Steuererklärung" from "Steuererklrung". Dates taken from the lines' own words.
- **What the net in code catches:** "move", "die Verteilung" and "den Tag" — a name and two date labels with no word of the line. None of them can reach a matter any more (`Welcome.grounded`, tested).
- **Still not right:** Apple's model sometimes calls "started am 2.12." a deadline rather than an appointment. Parked, not in this feature.

## The owner's own try

**TestFlight 0.5 (250) and (251), the owner's second iPhone, signed in as a new tester (rchille@babbel.com), 13 November.**

- **250:** the welcome, then the first step. The start credit was given — the beeserver's ledger shows the grant at 10:14 — but "Use Pro" stayed off, so nothing was read with it: the owner, "pro was not used or inactive". Fixed in 251: the start credit switches "Use Pro" on while the owner has never set it themselves.
- **251:** the app deleted and installed again, the matter deleted first. The credit was asked for once per install (the second fix), the beeserver gave the device its token back with the credit untouched, and the first line was read by Pro. "Der umzug ist für den 2.12.2026 geplant" became the matter **Umzug**, with an appointment on 2 December and the line "Pro · GPT-6.1 Terra" under it. The owner: **"it works, pro reads the first line now"**.
- **The beeserver afterwards:** one grant of 1,500,000 micro-dollars, one read paid from it — 4,947 micro-dollars, about half a cent. The rest is left.

**On the Mac, by hand, from the branch's build on an empty store of its own (13 November).** The welcome's four pages, the first step, a typed line read with the owner's Pro: "Der umzug ist für dne 1.2.2027 geplant" became **Umzug** with an appointment on 1 February 2027. The name box filled in with the Mac's user name. Along the way the owner found, and the build fixed: a box inside the field, the example card with no outline on white, a second card for typed words, the file name and "what would be sent" on words read on the Mac, the iPhone's pictures cut and grey-edged, and the overview's title and search over nothing.
