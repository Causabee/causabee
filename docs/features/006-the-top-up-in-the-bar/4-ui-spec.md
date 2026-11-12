# F006 · The top-up in the bar — Looks

## Screens and states

One place: the plan in Settings — `PlanSettings` with `ProBar` in it — and the same in the setup assistant. The plan's title and its date are not touched; of its buttons and the plan sheet, only the top-up's name with Pro (AC-9).

| State | What is shown |
|---|---|
| Pro, no top-up left | The month's bar alone, as today: "40 %  left", yellow. Today's notes ("Used for this month …") |
| Pro and a top-up, the month in use | The month's bar; 12 points under it the top-ups' bar, its length on the month's scale (one top-up a third): "67 %  of a Pro month in top-ups", dark gold. Under both, one line: "Starts anew on 1 December · top-ups carry over" |
| Pro, the month used, the top-ups in use | The month's bar at "0 %", its sliver as today; the top-ups' bar going down |
| Running low (together a fifth or less) | The bar in use and its number in orange, the other in its own colour |
| A new month with a top-up left | The month's bar full again, the top-ups' bar where it was |
| More than a Pro month of top-ups | The top-ups' bar full; the number says more: "133 %" |
| Top-ups alone, no Pro | Only the top-ups' bar, dark gold, "33 %  of a Pro month in top-ups", and the line "Top-ups carry over from month to month." Used up: today's note ("Used. Apple's model on this device reads what comes in — or buy another top-up.") |
| The beeserver not reached | What it said last, as today; nothing said ever: no bar, as today |
| Without Pro and without top-ups | No bar, as today |

The picture: `bars.svg` in this folder — states 1, 2 and 3.

## Words

| Where | Text |
|---|---|
| The month's bar, after the number | left *(as today)* |
| The top-ups' bar, after the number | of a Pro month in top-ups |
| The line under the bars, with Pro | Starts anew on 1 December · top-ups carry over |
| The line under the bars, top-ups alone | Top-ups carry over from month to month. |
| The top-up's button and choice, with Pro (AC-9) | Add a top-up · <price> — was "Top up this month · <price>" |
| Gone | "· 33 % of it from top-ups" — the second bar says it |

The notes, the plan’s names and the buttons keep today’s words, but the top-up’s with Pro (AC-9). Every text names no source: the bar is about Pro, not what comes in.

## On each device

The same view on the Mac, the iPhone and the iPad: the plan's card in Settings, as wide as its form. The bars stretch to the card's width; nothing changes per device but the width.

## Undo, and what the user can take back

Not needed: the bars only show; nothing is done from them.

## Accessibility

- VoiceOver reads each bar as one element: "This month's Pro: 40 percent left", "Top-ups: 67 percent of a Pro month left".
- The number grows with Dynamic Type (`planNumberFont`, relative to `.largeTitle`), and the words with `.subheadline`, as today; at the largest sizes the words wrap under the number.
- Dark mode: the top-ups' colour has its own dark step. The two bars differ in more than colour: each has its own number and words, so neither depends on telling yellow from gold.

## Design system

- **Parts:** today's `ProBar` meter, once per bar — the number in `Theme.planNumberFont`, the words in `.subheadline` `.secondary`, a `Capsule` on `Theme.line`; the line and notes in `.footnote` `.secondary`. Inside `PlanSettings`'s `Section` in a grouped `Form`, as today.
- **Colours:** the month `Theme.bee`, as today; low `Theme.warning`, as today.
- **New: `Theme.topUp`** — light `#B38F00` (`yellowDark[3]`), dark `#CCA800` (`yellowDark[2]`): a step of the yellow ladder, darker than the bee. Why none fits: `bee` is the month; `gold` means a link (T2); `warning` means late; `done` is grey, and would say the top-up is used. Its row in `docs/design-system/colors.md`: "the top-ups' bar in the plan — never for anything else".

## Picture

`bars.svg` in this folder: the three states — the month first with the top-ups waiting, the month used with the top-ups low, top-ups alone above a Pro month. Light mode.
