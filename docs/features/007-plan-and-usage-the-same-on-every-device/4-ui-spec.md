# F007 · Plan and usage, the same on every device — Looks

## Screens and states

The picture is `wireframes.html` in this folder (published as "Pro and Its Switch"): where it lives, cases A to H, and buying. Three places change:

**1 · Settings, its top** (iPhone and iPad). Two rows in one section, before Mail:
- "Plan and usage" — the plan's name and its line, a thin bar (4 points) under it when there is Pro or a top-up, a chevron; opens the plan page.
- "Use Pro" — the switch, with its line under it.

**2 · The plan page** — "Plan and usage" on the iPhone and the iPad (pushed in Settings' navigation), the "Plan" pane on the Mac. Top to bottom: the card (name, corner, the bars, their line, the top-up button), "Use Pro", then Change plan, Manage subscription and Restore Purchases as today.

| Case | The card | The switch |
|---|---|---|
| A · nothing bought | "Causabee", "Free", "3 open matters. Apple's model on this device.", **See the plans** | off; a tap opens the plans |
| B · Plus, no top-ups | "Causabee Plus", "renews 14 November", **Pro, now and then · price** | off; a tap opens the plans |
| C · top-ups only | name and corner say why — "Free", "Plus · renews …", "Pro ended 7 November"; the top-ups' bar; **Pro, now and then · price** | on or off |
| D · Pro | the month's bar; **Add a top-up · price** | on or off |
| E · Pro and a top-up | both bars; **Add a top-up · price** | on or off |
| F · Pro, used up | "0 %", the note, the filled **Add a top-up** | on, waiting |
| G · not counted yet | an empty bar, "–  not counted yet" | as set |
| H · ends, or payment problem | "ends 28 November" or "payment problem", as today | as set |

Off: every bar greyed (`Theme.strongLine`), its number in `.secondary`, its words ending "· not in use".

**3 · The Mac's Settings window** — two panes in its toolbar: **General** (today's form without the plan) and **Plan** (the page). The window opens on General.

**The bee and the chat** keep their places; only their words change.

## Words

| Where | Text |
|---|---|
| Settings row | Plan and usage |
| Its line, Pro | Causabee Pro · 59 % left — and "· 33 % in top-ups" with a top-up |
| Its line, top-ups only | Causabee · 37 % in top-ups — "Causabee Plus · …" with Plus |
| Its line, nothing | Causabee · Free — or "Causabee Plus" |
| Its line, used up | Causabee Pro · used for this month |
| Its line, not counted | Causabee Pro · not counted yet |
| Its line, switch off | … · not in use, after the rest |
| The page's title | Plan and usage — the Mac's pane: Plan |
| The corner after Pro ended | Pro ended 7 November |
| A bar off | left · not in use — of a Pro month in top-ups · not in use |
| The bar not counted | – · not counted yet; its line: Shown once Causabee reaches its server. |
| The switch | Use Pro (was "Pro on") |
| Its line, on | GPT-6.1 Sol reads what comes in, names disguised first. *(the reading model's name, as today)* |
| Its line, off | Off: Apple's model on this device reads what comes in. Nothing leaves it. *(as today)* |
| Its line, waiting | On, waiting: nothing left to use until 28 November. — Pro ended: On, waiting: Pro has ended. A top-up goes on at once. |
| Its line, nothing bought | Needs Pro or a top-up. |
| The top-up, without Pro | Pro, now and then · price *(as today, now with Free too)* |
| The bee's menu | Use Pro — Stop using Pro (were "Turn on Pro", "Turn off Pro") |
| The Mac bee's help | Opens the chat. Right-click to use Pro — … to stop using Pro |
| The bee read aloud | Using Pro — Not using Pro (were "Pro on", "Pro off") |
| The chat's offer, button | Use Pro (was "Start Pro") |
| Asked first | Use Pro? (was "Turn on Pro?") |
| The device's answer without Pro | Asking needs Pro. Use Pro on top, then ask again. |
| When the month runs out | This month's Pro is used up. It waits until it starts anew — or a top-up. Apple's model on this device reads what comes in meanwhile. |
| When Pro ends | Causabee Pro has ended. A top-up goes on at once; meanwhile Apple's model on this device reads what comes in. |
| Elsewhere, Pro not in use | Pro is not in use. Use Pro with the bee for this. (was "Pro is off. Turn it on with the bolt for this.") |
| The Mac's plan footer | Change or cancel it on your iPhone or iPad: this Mac follows through iCloud. *(as today, until the Mac buys)* |

Short sentences; no source named alone — what is read is "what comes in".

## On each device

- **iPhone and iPad:** the two rows at the top of Settings' form; the row pushes the page in the same navigation stack; the page is a grouped `Form`.
- **Mac:** the Settings window gets a toolbar with two panes; Plan is the same page in a grouped `Form`, the window's width.
- The card, the bars, the words: one view (`PlanPage`) on all three.

## Undo, and what the user can take back

The switch is its own undo: on and off, nothing is lost (AC-4). Purchases are the App Store's.

## Accessibility

- The row reads as one: "Plan and usage, Causabee Pro, 59 percent left, 33 percent in top-ups"; a button that opens the page.
- Each bar as in F006, with "not in use" when off and "not counted yet" when empty.
- The switch is a system `Toggle` labelled "Use Pro", its line its hint.
- Dynamic Type: the row's line wraps; the thin bar stays under it.
- Off is told by words as well as grey; dark mode through the tokens.

## Design system

- **Parts:** the system's `Form`, `Section`, `NavigationLink` row and `Toggle`; `PlanRow` (today's `SettingsPart` neighbour) for Change plan and Manage subscription; F006's `ProBar` for the bars, a 4-point version of its bar in the row; `.filledButton()` and `.quietButton()` for the top-up as today; on the Mac a `TabView` in the `Settings` scene with `Label`s — the HIG's Settings window with panes.
- **Colours:** `Theme.bee` and `Theme.topUp` (F006) for bars in use, `Theme.warning` when low; **off: `Theme.strongLine`** for the bar and `.secondary` for its number — no new token: a firmer grey frame colour, the one grey between `line` and `done` (done would say used up).
- **Type:** `Theme.planNumberFont` on the page as today; the row in `.body` and `.footnote` `.secondary`.
- **Symbols:** the switch keeps `bolt.fill` in `Theme.gold`; the Mac panes `gearshape` (General) and `creditcard` (Plan).

## Picture

`wireframes.html` in this folder, published at https://claude.ai/artifact/UYiAmw4fGqjajRr5RkYFNS — the row in its states, the page in every case, buying, the Mac's panes.
