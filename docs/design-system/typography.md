# Typography

How Causabee sets its words on the Mac, the iPhone and the iPad. The rules this serves are H4, T3 and T4 in [../design-system.md](../design-system.md). The sources are `Theme` in `Sources/Causabee/Theme.swift`, `Sources/Causabee/TextSize.swift` and `Sources/CausabeePhone/Parts.swift`.

## Two faces

- **Source Serif 4** — the names of matters, and the one big number of the plan. It ships with the app (`SourceSerif4.ttf`, made known once by `Theme.registerFonts()`). It is used only through the `Theme` fonts below.
- **SF, the system's face** — everything else: steps, reasons, facts, rows, buttons, chips. It is used through the system's text styles (`.body`, `.callout`, `.caption` …), never by a point size.

The serif names a matter. Running text is never in the serif.

## The serif, by role

| Font | Size | Grows with | Used for |
|---|---|---|---|
| `Theme.titleFont` | 26 | `.largeTitle` | The Mac: a matter's name on top of its page. |
| `Theme.cardTitleFont` | 22 | `.title` | The Mac: a matter's name on its overview card. |
| `Theme.rowTitleFont` | 17 | `.headline` | A matter's name on its one line in the overview, so a matter never looks like one of its tasks. The Next card's step, on every device. |
| `Theme.planNumberFont` | 34 | `.largeTitle` | What is left of the month's Pro: the plan's one big number. |
| `Theme.phoneTitleFont` | 34 | `.largeTitle` | The iPhone: the overview's and a matter's name on top of the page. |
| `Theme.padTitleFont` | 30 | `.title` | The iPad: a matter's name in its bar. |
| `Theme.phoneCardTitleFont` | 22 | `.title2` | The iPhone: a matter's name on its overview card. |

On the Mac the sizes are multiplied by `Theme.textScale`. On the iPhone and the iPad they grow with Dynamic Type, through `relativeTo:`.

A new serif size is a new `Theme` font with a `///` line, never a `.custom("Source Serif 4", …)` in a view. Two are written out today, at 30 and 18 points (`MailSetup.swift:567`, `MatterStatusView.swift:1124`); they are parked.

## The system's text styles

On the iPhone and the iPad these are Apple's own and follow the reader's text size. On the Mac, `TextSize.swift` redefines them a fifth larger than the Mac's own sizes, because Causabee is read in, and the Mac's sizes are those of a list of files. `-text.scale 1` on the command line tries another scale.

| Style | Mac (× 1.2) | iPhone and iPad (default size) |
|---|---|---|
| `.largeTitle` | 31 | 34 |
| `.title` | 26 | 28 |
| `.title2` | 20 | 22 |
| `.title3` | 18 | 20 |
| `.headline` | 16 bold | 17 semibold |
| `.body` | 16 | 17 |
| `.callout` | 14 | 16 |
| `.subheadline` | 13 | 15 |
| `.footnote` | 12 | 13 |
| `.caption` | 12 | 12 |
| `.caption2` | 12 | 11 |

So the same style name gives each device its right size. A view written once for both apps stays right on both.

A button's words on the Mac take the system's small size; `.macBody()` sets them at the Mac's text size, so they stand level with the lines around them. `QuietButtonStyle` and `InkButtonStyle` already do it.

## Roles: the Next card is the model

Each kind of text has one style, everywhere. The Next card sets them:

| Role | Style | Colour | Example |
|---|---|---|---|
| A label on the yellow or the orange | `BeeChip`: `.caption.weight(.semibold)`, capitals | black on `bee`; `onInk` on `warning` | NEXT · FROM CAUSABEE, OVERDUE |
| What to do, the step | `Theme.rowTitleFont` | `.primary` | "Read and sign the Sunrise contract" |
| Why, the reason under it | `.callout` on the Mac, `.subheadline` on the iPhone and the iPad | `.secondary` | "The offer ends on Friday." |
| A status line | `.caption` | `.secondary` | "Causabee is on it …" |
| A note on the step | `.footnote` | `.secondary` | "Something changed since this was written." |
| A section's heading | `SectionHeader`: `.caption.weight(.semibold)`, capitals, a count on the right | `.secondary` | TASKS, and "3 open" on the right |
| A small button's words | `.caption.weight(.medium)` | `.primary` | Update now |

What stands beside the Next card is set as the Next card is: a fact as its reason, a heading as its step (T4). Summary and Good to know do not follow this yet; that is parked as polish (11 November).

## Emphasis

- **Weight** says what kind it is, not how important: `.semibold` for chips and headings, `.medium` for a button's words. Running text is regular. No `.bold` in a line of text.
- **Colour** says how much it asks to be read: `.primary` for the thing itself, `.secondary` for what explains it, `.tertiary` rarely. See [colors.md](colors.md).
- **Capitals** only through `BeeChip` and `SectionHeader`. Never `.uppercased()` on a sentence.
- **Numbers that change** in place — a count, "2 of 7" — take `.monospacedDigit()`, so they do not jump.

## Long text

- A line that may run long wraps: `.fixedSize(horizontal: false, vertical: true)` in a stack, rather than being cut off.
- `.lineLimit(1)` only where one line is the design (a row's source, a name in a bar), and then the full text is reachable another way.
- Large text: every screen is looked at with the largest Dynamic Type size on the iPhone, and with `-text.scale 1.6` on the Mac, before it is done.

## Do and don't

- Do use a `Theme` font for a name, a text style for everything else.
- Do give a new kind of text the style its kind already has elsewhere (T4).
- Don't write `.font(.system(size:))` on text, or `Font.custom` outside `Theme.swift` and `Parts.swift` (T3, checked by `scripts/ui-check.py`).
- Don't size an SF Symbol by points: give it the text style of the words beside it, or `.imageScale` (H5).
- Don't lower contrast with `.opacity` on words; use `.secondary` or `.tertiary`.
