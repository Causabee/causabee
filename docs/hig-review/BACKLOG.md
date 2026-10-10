# Backlog from the HIG review and the purpose-layer experiment

Written 2026-10-10, on the branch `hig-fixes` at `7aad9b5`. What is still open after five rounds of
fixes, as issues to pick up one by one. Line numbers are for this branch; paths are under `Sources/`.

- IDs like **M5** or **B12** are findings of `HIG-REVIEW.md` (section 3), where each has its HIG page.
- **X1–X3** are the three most important findings of the purpose-layer experiment (branch
  `purpose-layer-experiment`, `design-rules/reports/2026-10-10-report.md`).
- Effort: **S** under an hour, **M** half a day, **L** more than a day.
- "Look" means the fix changes what is seen, so it is the owner's choice before it is code.

## Assessment

Of 50 findings, 16 are fixed in whole or in part, 14 are left alone on purpose, and the rest are
open below, with the three from the experiment and two checks that came up while fixing. The Mac no longer has an open High finding;
the iPad's are fixed too. What is left falls into four kinds:

1. **Trust** (X1, X2, X3) — the app's own promise: nothing sent unasked, nothing lost, said plainly.
   Small in code, large in what they mean. First.
2. **Unproven fixes** (V1, V2) — undo and the UI tests. Everything later builds on these.
3. **Completing what was started** (#6–#12) — the same fix on the remaining places.
4. **Choices about the look** (#13–#16, and "Decided") — nothing to code until decided.

## Do first

| # | Issue | Where | What to do | Effort |
|---|---|---|---|---|
| **X1** | ~~Auto is switched on with one click and nothing visible says what it does.~~ **Done 2026-10-10:** the first time a bolt is pressed to turn Auto on, a question says what it does — read at once, sent pseudonymised to the named model, without asking first, what a mail costs — with "Turn Auto On" and Cancel. Agreed once, the bolt is a bolt again. Seen on the iPhone (`raw/fixes/iphone-3-auto-asks-first.png`); the Mac and the iPad are built, not tried. The switch in the iPhone's Settings is unchanged: it says all this beside itself. | `Causabee/ModelChoice.swift` (`AutoQuestion`), the three bolts | — | — |
| **X3** | ~~Errors from the AI service are shown raw.~~ **Done 2026-10-10:** every failure of asking has its own sentence with what to do — busy, wrong key, no credit, too many requests, too much text, cut off, declined — and no status number or service answer reaches the owner (`Claude.Failure.forPeople`, through `plainWords`). The log and the command line keep the full text. The setup sheet's four raw errors go the same way. Four unit tests; both apps build; not provoked in a running app. | `MatterCore/Claude.swift` | — | — |
| **X2** | ~~Removing is protected for some things and not for others.~~ **Done 2026-10-10:** a person taken out of a matter comes back with Undo — role, mentions, and the rule that kept them away goes. The Mac's right-click item is marked destructive. Unit-tested; not tried in the running apps. | `MatterCore/Model/PartyBook.swift` (`removeByHand`) | — | — |
| **V1** | ~~Undo has not been tried in the running apps, and there is no Redo.~~ **Done 2026-10-10:** on the Mac a task was deleted, brought back with Edit ▸ Undo (same words, day, "asked 2×", source), removed again with Redo and brought back once more. Redo is in for all six kinds. Still untried: on the iPhone (shake) and iPad, and with a reminder or Calendar entry attached. The Edit menu says "Undo", not "Undo Delete Task". | `MatterCore/Model/DeleteByHand.swift` | Try on a device. | S |
| **V2** | **The iPhone's UI tests: 14 run, 13 passed, 1 failed once and passed when run again by itself** (`ThreadTests.testALongAnswerIsReadFromItsBeginning`: "The question is not in the thread" — the question did not show within 8 seconds). Not explained; it may be chance, or the assistant's thread now taking its width a moment later. **The Mac's UI tests could not run:** this Mac asks for a password before a test may control it (Automation Mode is off). | `scripts/mac-tests.sh` | Owner: `automationmodetool enable-automationmode-without-authentication`, quit Causabee, run `scripts/mac-tests.sh`. Watch the one iPhone test on the next runs. | S |

## Then: finishing what was started

| # | Issue | Where | What to do | Effort |
|---|---|---|---|---|
| 6 | **B2, rest — the contact and detail sheets still lose typed text** on a swipe (iPhone); they are shared with the Mac. | `Causabee/PageFind.swift:342`, `:406` | `.keepsWhatWasTyped([...])` inside their iOS branch. | S |
| 7 | **Mac popovers lose typed text on a click beside them** — task, date, person and link editors (the experiment's weakest rule, 19%). | `Causabee/MatterStatusView.swift:1595`, `:1989`, `:2158`, `:2562` | Keep the draft in the row's state so reopening shows it, or do not close on an outside click once something changed. | M |
| 8 | **B12 — three sheets on top of each other**: Welcome → Settings → Mail account. | `CausabeePhone/Welcome.swift:43`, `CausabeePhone/SettingsSheet.swift:115` | Push Settings and Mail account inside one navigation stack. | M |
| 9 | **M5 — most matter actions are not in the menu bar**: Pin, Rename, Merge, Export, Close, Open Again. | `Causabee/CausabeeApp.swift:974` | Build the Matter menu, the ⋯ and the sidebar's context menu from one list. | M |
| 10 | **The setup sheet's middle steps have no way out, and "Use another account" deletes a login at once.** | `Causabee/SetupAssistant.swift:551` | A Later/Close on every step; ask before the Keychain entry goes. | S |
| 11 | **I2 — pull to refresh ends before the mail check does.** | `CausabeePhone/OverviewScreen.swift:241` | Await the running check in `refreshable`. Look: the system's spinner then shows beside the bee loader — choose one. | S |
| 12 | **M25 — "Set Up Causabee …" and "Try the Demo" stand above Settings…** although the code asks for after. | `Causabee/CausabeeApp.swift:140` | Find why the built menu differs; check with the menu read-out in `raw/runtime-checks.md`. | S |

## Needs a choice about the look first

| # | Issue | Where | The choice | Effort |
|---|---|---|---|---|
| 13 | **B1 — tap targets under 44 points** (⋯ 30 × 26, tick box 26 × 26). Two ways of enlarging only the touch area did not work: a menu answers where its label is laid out. *Waiting, at the owner's word.* | `CausabeePhone/MatterScreen.swift:1092` and five like it | A larger label moves the row's text a few points — accept that, or leave it. | S |
| 14 | **M7, rest — in five Mac popovers the main button looks like Cancel.** | `Causabee/MatterStatusView.swift:873`, `:2056`, `:2173`, `:2504`, `:2610` | Fill Save/Start as the task editor does, or keep them quiet. | S |
| 15 | **I1 — no title in the iPhone's bar once a matter is scrolled.** | `CausabeePhone/MatterScreen.swift:208`, `CausabeePhone/OverviewScreen.swift:250` | Show the matter's name in the bar when the header has scrolled under. | S–M |
| 16 | **"Export failed" is an alert with one OK** (Mac and iPhone). | `Causabee/MatterStatusView.swift:232`, `CausabeePhone/MatterScreen.swift:283` | A line by the menu instead, or keep the alert: a rare error may be one. | S |

## Later

| # | Issue | Effort |
|---|---|---|
| 17 | **P4 — no hover feedback on the iPad.** Needs a real iPad with a pointer to look at. | M |
| 18 | **P5 — no drag and drop on iPhone and iPad**, though the Mac takes drops in the same places. | M |
| 19 | **P8 — several windows are possible on the iPad but not designed for.** Support it or switch it off. | S to switch off, L to support |
| 20 | **P7 — the icon picker is a fixed-height sheet on the iPad**; a popover there, and a scroll view for large text. | S |
| 21 | **I3 — no swipe actions on task, date, file and link rows.** The rows are cards, not a list. | M–L |
| 22 | **M19 — the open matter is not restored at the next start; the first window opens at its smallest.** | S–M |
| 23 | **M18 — nothing lights up under a drag; files cannot be dragged out.** | M |
| 24 | **M22 — two open panels block the whole app instead of hanging on the window.** | S |
| 25 | **M11 — full screen was never looked at** with the hand-drawn window frame. | S to look |
| 26 | **M12 — text size is only a launch argument;** View ▸ Bigger/Smaller, and Settings in the same size. | M |
| 27 | **M2, rest — typing a name in the sidebar does not jump to it**; Tab into the sidebar is built, not tried. | S–M |
| 28 | **M6, rest — ⌘G / ⇧⌘G were built, not tried.** | S |
| 29 | **Structural: M3, P3 — the sidebar and the columns are hand-built** on Mac and iPad: no dragging the divider, no edge swipe, a flat sidebar on 26. The system's containers would also settle M11. A design decision as much as work. | L |

## Decided: left as they are

Each would change something that is meant to look or work as it does; `HIG-REVIEW.md` gives the
compliant alternative for each. Not planned unless the owner reopens them.

M14 the Matter menu after Edit · M15 " …" with a space · M13 the floating bee and the custom
controls · M20 the black tint · M21, B4, B7, B8 bar backgrounds and glass details · B9 the
overview's own search field · B6 the assistant's hand-built header · M10 ⌥Space for dictation ·
M17 the quicker tooltips · M24, B13 dates in English form.

## Confirmed by the owner (2026-10-10)

- **M1 — closing the window quits Causabee.** Yes.
- **The new words**: the View menu's titles, "Get New Mail", "Next Matter" / "Previous Matter",
  the two hint texts that replaced the command-line ones, and the delete dialogs that mention Undo. Yes.
