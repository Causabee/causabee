# F005 · The chat in two depths — Proof

## Each criterion

| Criterion | Test | Result |
|---|---|---|
| AC-1 | `ChatDepthTests` "F005 AC-1 · The light text holds what a quick question needs, with the same ids", "A full matter's light text is at most half", "No light text where the sheet is short already", "A quick question goes light". The pressure test on the full demo matter: light sends 48% of it, the first question $0.019 where it was $0.046 (`tests/results.md`). On the owner's own matter, 12 November: a quick question went `chat-light` for $0.023 where deep cost $0.047 | pass |
| AC-2 | "F005 AC-2 · A question that needs the whole matter goes deep"; the pressure test: 7 of the 10 such questions deep at once | pass |
| AC-3 | "F005 AC-3 · A light answer that lacks something is asked again deep, and only that answer is shown", "… that cites what it was not shown …", "… that has what it needs is shown as it is: one ask"; the pressure test: 3 went light, lacked something, were asked again deep; no answer said "not there" where today found it | pass |
| AC-4 | "F005 AC-4 · An element only the whole matter holds sends the question deep". On the owner's matter, 12 November: a question naming a thing only the fifth-newest item's own words hold went deep at once — the light text keeps the newest three | pass |
| AC-5 | "F005 AC-5 · A follow-up never goes lighter"; "F005 AC-5 · A follow-up is one within the cache's 30 minutes; later, the depth is picked anew" (changed after its gate, 12 November, approved). On the owner's matter: follow-ups within 30 minutes stayed at their depth and read the cache; a question 30.5 minutes later was picked anew | pass |
| AC-6 | "F005 AC-6 · The depth depends on the question and the matter alone" | pass |
| AC-7 | "F005 AC-7 · Tested before it ships: the pressure test and its blind reading are kept". The pressure test, `tests/results.md`: as good as today's on every case; read blind by Claude Fable 5.2 in both orders, no two-depth answer worse, today's worse on two. Terra for light: below the bar, so `chat-light` stays on Sol | pass |
| AC-8 | App "F005 AC-8 · The chat's three jobs, the app's and the server's"; server "F005 AC-8 · The ledger tells light from deep". The live ledger, 12 November: rows `chat-light` and `chat`, apart | pass |

## Everything else still works

- **Unit tests:** 658 in 140 suites pass, 12 November, after the last change.
- **The server:** 38 tests in 5 files pass, 12 November. Deployed by the owner on 11 November (`b1a0e714`), with the F005 jobs; unchanged since.
- **The schema:** untouched (`git diff main -- Sources/MatterCore/Model/Models.swift` is empty).
- **The screen tests,** 11 November, on the build before the two changes of 12 November: iPhone 87 (7 skipped as made, none failed), iPad 5 of 5, Mac 33 (two toolbar tests passed when run again alone). **Not run again** after the AC-5 change and the Pro fix: both change no screen; the iPhone and Mac apps build after them.
- **The UI check:** `ui-check.md`, "Verdict: pass".
- **Found on the way, 12 November:**
  - The Pro fix, on main in its own commit (885bae1): with a top-up and no Pro subscription, the bee and the chat counted Pro off; the owner could not turn it on on the Mac. Now one rule, `Plan.proIsOn`, with `ProOnTests`.
  - AC-5 changed after its gate: the chat is kept from day to day, so "the same conversation" is now the cache's 30 minutes. The owner: "Approved". In the manifesto, section 5, with its test.
  - Parked: the chat's memory past its last four turns (the owner's idea).

## The AI's answers

`tests/results.md`: the pressure test on the full demo matter, all demo matters merged in a copy of the store — invented text only. $0.36 for the test, $0.61 for Fable 5.2's blind reading.

## The owner's own try

The F005 build on this Mac ("Causabee 0.5 Beta 133", signed, not notarized, never published), the Doctolib matter, 12 November. Read from the ledger in numbers only; no question or answer was read.

| Time (UTC) | Build | What went | Cost |
|---|---|---|---|
| 07:29–07:32 | before the AC-5 change | 4 questions, all deep: the old thread's answers counted as deep | $0.048 first, $0.003–0.006 the others |
| 08:03–08:05 | with it | 5 questions; the first deep by AC-4, the others its follow-ups | $0.047 first, $0.003–0.004 the others |
| 08:36–08:37 | with it | "What's next?" and a follow-up, both `chat-light`, no deeper ask | **$0.023** first, $0.003 the follow-up |

The owner: "i did 4 questions in doctolib matter, perfect answers".

Not measured yet: the share of first questions that go light over a week of the owner's use.
