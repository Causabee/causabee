# Colour tokens

How Causabee's colours are used on the Mac, the iPhone and the iPad. The rules they serve are T1 and T2 in [../design-system.md](../design-system.md). The source is `Theme` in `Sources/Causabee/Theme.swift`.

## Where they come from

Two ladders of ten steps each, in `Palette`:

- **yellow**: from the bee's `#FFDB0D` out to white (`yellowLight`) and down to dark brown (`yellowDark`);
- **warm grey**: from `#A3A29B` out to white (`greyLight`) and down to black (`greyDark`).

Every token is a step of these ladders, with three exceptions: the honey of the chat, the warning's orange and the dark window. A view never reads `Palette` itself. It uses a token.

Most tokens adapt: one value in light mode, one in dark. Two are **fixed** — `bee` and `honey` — so the yellow is the same yellow everywhere. Words on them are therefore black in both modes.

## The tokens

### What a colour means

| Token | Light | Dark | Use it for | Never for |
|---|---|---|---|---|
| `Theme.bee` | `#FFDB0D` fixed | | The pills (`BeeChip`: NEXT, SUMMARY), the send button, the bee's own buttons (`AssistantButton`, `CornerBee`), a control that is on (Reading, Auto). Black words on it. | Decoration. A background for a whole card. |
| `Theme.beeSoft` | `#FFF5C8` | `#3A3528` | What waits for the owner: `.waitingTile()` — the Next card when something is to do. The thing in hand above the chat's field. | Anything that does not wait for the owner. |
| `Theme.honey` | `#FFE23E` fixed | | What the owner said in the chat: their question's bubble. Black words on it. | Anything Causabee says. |
| `Theme.gold` | `#7F5E00` | `#FFE03A` | Links and link-like buttons (`.buttonStyle(.gold)`), where the Mac would put its blue. Words in it read on white. | A filled button. A heading. |
| `Theme.warning` | `#C76600` | `#FF9E33` | Late, missing, not done: OVERDUE, FOLLOW UP, an overdue line on a card. `Theme.onInk` words on it. | An accent, an emphasis, an error that is not late. |
| `Theme.done` | `#53524A` | `#D0D0CC` | Done, taken in, read: a checkmark, a step of the setup that is done, the frame of what is known. | A disabled control (`.secondary` is that). |
| `Theme.topUp` | `#B38F00` | `#CCA800` | The top-ups' bar in the plan, under the month's yellow (F006). | Anything else. |
| `Theme.beeMark` | `#22211B` | `#FFDB0D` | The working bee's stripes (`BeeLoader`, `BeeMark`). | Anything else. |

There is no green and no blue anywhere. Done is grey.

### Surfaces

| Token | Light | Dark | Use it for |
|---|---|---|---|
| `Theme.page` | `#F5F5F4` | `#141310` | Under a matter's cards and the overview's: the page the white cards stand on. |
| `Theme.card` | `#FFFFFF` | `#22211B` | A card on the page (`.journalCard()`, `.phoneCard()`, `Card`), a field on a card (`.cardField()`). |
| `Theme.canvas` | `#FFFFFF` | `#141310` | The window itself where there is no page under it. |
| `Theme.box` | `#F5F5F4` | `#3A3932` | A box that stands out from a card: Summary, a date on the plan, an empty section, `.box()`, `.quietBox()`, `.phoneBox()`, a matter's icon tile. |
| `Theme.mark` | `#ECECEA` | `#3A3932` | What was jumped to: a search result, a task opened from elsewhere, the open row of the sidebar. |

On the page, the rule is: **page under, card on it, box inside the card.** Never a card inside a card, never a box on the page without its card.

### Ink and lines

| Token | Light | Dark | Use it for |
|---|---|---|---|
| `Theme.ink` | `#22211B` | `#ECECEA` | The filled button's ground (`.filledButton()`). |
| `Theme.onInk` | `#FFFFFF` | `#0B0A05` | Words on `ink` and on `warning`. |
| `Theme.line` | `#E3E3E0` | `#3A3932` | A thin frame or divider: `.quietBox()`, `.phoneCard()`, `RowDivider`. |
| `Theme.strongLine` | `#C7C6C2` | `#6C6B63` | The firmer frame of a box that asks for the owner: `.box()`, an unticked tick. |

### Words

Words are the system's, so they follow light, dark and higher contrast by themselves:

| Style | Use it for |
|---|---|
| `.primary` | What is read: a task, a fact, a name, a step. |
| `.secondary` | What explains it: a reason, a date line, a count, a source, a heading in capitals. The most used colour of words in the app. |
| `.tertiary` | Only what is nearly not needed: a row's chevron, a remove ×, a time, who a line came from. Rarely. |
| `Color.secondary.opacity(…)` | A quiet fill: the grey button (0.12, 0.2 pressed), a quiet chip (0.14), the open sidebar row (0.08). |

## Pairs

What may stand on what:

| Ground | Words |
|---|---|
| `bee`, `honey`, `beeSoft` | black (light), `.primary` on `beeSoft` |
| `ink` | `onInk` |
| `warning` | `onInk` |
| `card`, `box`, `page`, `mark` | `.primary`, `.secondary`, `gold` for a link, `warning` for late |

Words on the yellow are written `.black` in 15 places today, because there is no token for them yet. `Theme.onBee` is parked (the UI check of 11 November); until it exists, black on `bee` or `honey` is the one named colour that is right.

## Do and don't

- Do take a colour from `Theme`, or from `.primary`, `.secondary`, `.tertiary`.
- Do let yellow mean one thing: something waits for the owner, or it is the bee herself.
- Do check a new screen in dark mode before it is done.
- Don't write `Color(red:…)`, a hex value, `#colorLiteral`, or `.black`, `.white`, `.red`, `.blue`, `.green` … (T1, checked by `scripts/ui-check.py`).
- Don't add a token without a meaning that none of these has. A new token goes into `Theme`, with a `///` line that says what it is for, and into this file.
- Don't paint the drawings of the film and the website by these rules: `IntroOpener`, `IntroShot`, `ShotView`, `PhoneShots` draw a picture of the app with fixed colours on purpose.

A shadow is black in both modes and is not a colour of the page: `.shadow(color: .black.opacity(…))` is fine.
