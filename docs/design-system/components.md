# Components

Which of Causabee's parts to use for what, on the Mac, the iPhone and the iPad. The rules this serves are C1 to C5 and G1 to G5 in [../design-system.md](../design-system.md). Colours are in [colors.md](colors.md), type in [typography.md](typography.md).

**Before you build a view, find its part here.** A view that looks like one of these is one of these. When none fits, see "A new part" at the end.

Where they live:

| File | What it holds |
|---|---|
| `Sources/Causabee/Theme.swift` | Shared by both apps: buttons, chips, headings, boxes, glass, sheets, icons, the chat's input |
| `Sources/Causabee/Journal.swift` | Shared by both apps: the matter page — cards, tiles, the plan, the Next card |
| `Sources/Causabee/Components.swift` | The Mac's own parts (the iPhone's target does not take this file) |
| `Sources/CausabeePhone/Parts.swift` | The iPhone's and the iPad's own parts |
| `Sources/CausabeePhone/Pad.swift` | The iPad's layout: `PadMetrics` |

## Surfaces

The page is grey, the cards on it are white, the boxes in a card are grey again. See [colors.md](colors.md), "Surfaces".

| Part | Use it for | Not for |
|---|---|---|
| `.journalCard()` | A card on the matter page or the overview: white, `Theme.cardRadius`, `Theme.cardInset` inside. | A box inside a card. |
| `.outlinedCard()` | A card alone on a white page, as the welcome's example matter: `.journalCard()` with a plain `Theme.line` round it, like the iPhone's `.phoneCard()`. | A card on the matter page or the overview. |
| `.journalRows()` | A card of rows that keep their own room (no inset). | |
| `.waitingTile(forYou)` | What waits for the owner: `beeSoft` when `forYou`, the same room without colour when not, grey when out of date. Inside a card, `Theme.tileInset` from its edge. | Anything that does not wait for the owner. |
| `.waitingRows()` | What others must do: no card, a dashed line round it, so it never reads as something to do now. | The owner's own tasks. |
| `.planRow()`, `.planDate()` | A row of the plan; a date on the plan, as a grey block of its own. | |
| `.box(radius:)` | The Mac: a box that asks for the owner — a card to take in, a merge to decide. Grey, a firm frame. | Something already done. |
| `.quietBox(radius:)` | The Mac: what is done or on its way — a draft opened elsewhere, a card taken in. Grey, a plain line. | |
| `.phoneBox()` | The iPhone: the grey box of Next and Summary. | |
| `.phoneCard()` | The iPhone: rows or a card on white, a thin line round it. | |
| `Card { … }` | The Mac: rows in one rounded box, with lines between them. | |
| `PhoneEmptyBox` | A section with nothing in it yet: what goes in it, and the button to add it by hand. The Mac draws the same. | |

Not `.background(Theme.card, in: RoundedRectangle(cornerRadius: n))` by hand (C2). The UI check of 11 November found 40 of these; they are parked.

## Buttons

| Part | Use it for | Example |
|---|---|---|
| `.filledButton()` | The one thing to do here. Black, white words; a capsule on the iPhone, a small rounded one on the Mac. | Add, Save, Load |
| `.quietButton()` | What stands beside it. Grey. | Cancel, Not now |
| `.buttonStyle(.gold)` | A link in a line of text. | Edit, Show again |
| `.buttonStyle(.plain)` | An icon, or a whole row that is a button. | |
| `.buttonStyle(.rowIcon)` | The Mac: a small tool at the end of a row: one size, grey, a target big enough to hit. | edit, info, pin |
| `.phone`, `.phoneFilled`, `.phone(filled:wide:)` | The iPhone's own pair, when a view is only the iPhone's. | Write message, Done |
| `UpdateNowButton` | The one button that has Causabee write a matter again, wherever that is offered. | Update now |
| `SheetConfirm`, `SheetCancel` | Save or leave a sheet: the system's check and cross on glass on the iPhone and the iPad; the word on Return and Esc on the Mac. | |

- Never `.borderedProminent`: its words take the tint, which is black here — black on black.
- No new `ButtonStyle` (C1).
- In a view both apps share, `.filledButton()` and `.quietButton()`, not `InkButtonStyle()` or `PhoneButtonStyle()` (C4).
- What is pressed is a `Button`, not `.onTapGesture` (H1).

## Labels and headings

| Part | Use it for |
|---|---|
| `BeeChip(text:tone:)` | A label in capitals on the yellow (`.bee`: NEXT, SUMMARY), on the orange (`.warning`: OVERDUE, FOLLOW UP), or quiet (`.quiet`: OUT OF DATE). |
| `SectionHeader(title:detail:)` | A section's heading in small capitals, with a count on the right. |
| `ProLine` | Where something is out of reach without Pro: it says so before it is tried, and what would do it. Never yellow. |
| `AutoWaitLine` | Under what Auto writes while the matter has changed: when it will, and the button not to wait. |
| `SourceLink` | The Mac: opens where a fact came from. A door out, so it opens only on a click. |

## The matter page

| Part | Use it for |
|---|---|
| `NextCard(forYou:outOfDate:head:foot:)` | What comes next: the step on its tile, what can be done about it under it. One per matter. Its type is the model for the page ([typography.md](typography.md)). |
| `OutOfDateStep` | The step once the matter has changed under it: still there, grey, says it may no longer hold. |
| `DayTile`, `SetDayTile`, `ChangesDay` | A day's tile ("THU", "1"); "Set day" for a task with none; a tile that opens the calendar. |
| `.daySheet(isPresented:item:)`, `DaySheet` | The calendar for an item's day: a sheet on the iPhone, a popover on the Mac. |
| `WhenChips` | "When?" in one tap: this week, next week, later. |
| `JournalPills` | The filters over a journal: the open one on a white pill. |
| `PartTabs` | The parts of a matter as pills, a sign each, the open one filled and wide with its word. |
| `PageRows` | The Mac: the rows of a long list, drawn only near the screen, all of them while the page is searched. |
| `RowDivider` | The Mac: the line between rows in a card. |
| `MoreMenu { … }` | The Mac: the ⋯ at the end of a row — edit, move, remove, in one menu. The iPhone's rows draw their own ⋯ menu, with `.menuSigns()` for its icons. |

## A matter's identity

| Part | Use it for |
|---|---|
| `MatterIconTile(matter:size:)` | A matter's icon on a small grey tile, in front of its name wherever matters are listed. |
| `MatterIconMenu`, `MatterIconPicker` | Choosing the icon: by name in a menu; as a grid (a popover on the Mac, a sheet on the iPhone). |
| `SmallIconLabel` | A matter's icon small in front of its name, in a line of text. |
| `PhoneMatterCard` | The iPhone: one matter on the overview — what is open and whose, what comes next, what is overdue. |

## The chat and what is added

| Part | Use it for |
|---|---|
| `AssistantButton` (iPhone, iPad), `CornerBee` (Mac) | The bee in the corner: always yellow, always the chat. |
| `SendGlyph` | The send button's face: a black arrow on the yellow, or a black square to stop. |
| `CardFace` | What Causabee suggests, as a card: what it is, its title, its words, one button, × to put it aside. |
| `MicButton`, `ListeningBar`, `SpeechModelCard` | Speaking into a field: the microphone; the field as it listens; the one-time card to load the speech model. |
| `ProOffer` | On top of the chat while Pro is off: what Pro adds, in one line, and the one way to it. |
| `PhoneAutoButton` | Auto on and off, small, over the bee: the black bolt on the yellow when on. |
| `FilesComing` | Files being brought into a matter: how far, which file, a way to stop. |

The owner's question in the chat is drawn by hand three times (`AssistantView.swift:690`, `AssistantSheet.swift:663`, `:780`). One `QuestionBubble` is parked; until then, a new place that shows the owner's words copies none of them — it waits for that part.

## Glass

| Part | Use it for | Not for |
|---|---|---|
| `.onGlass(shape, tint:)` | A control that floats over the content: a capsule, a round button in a corner, a bar's button. Interactive glass on macOS 26 and iOS 26, a thin material on macOS 15. | A card, a row. |
| `.glassBehind(shape)` | A field over the content, the chat's field: glass behind it, its words stay sharp. | |
| `GlassEffectContainer` | Glass shapes that stand close together, so they read and move as one — the find bar's field and arrows (`MatterScreen.swift:562`). Raw `.glassEffect` is allowed only inside one. | A single shape. |

- No `.ultraThinMaterial`, `.regularMaterial` … by hand: the helpers carry them for macOS 15 (G3).
- Glass is for controls, never for content (G5).
- `.onGlass` is always interactive. Where a tap must not pass through — the iPhone's "New answer" pill — raw glass is kept for now; `.onGlass(_, interactive: false)` is parked.

## Reading and putting away

| Part | Use it for |
|---|---|
| `.tool()` | A small action — a link, a ⋯, a pin, a button that asks the AI. Gone while reading. |
| `.explanation()` | What the AI says about why, what it cost, where it looked. Gone while reading. |
| `ReadingButton` (Mac) | Reading on and off: black glasses on the yellow when on. |

Every new small action gets `.tool()`, and every new "why" gets `.explanation()`, so Reading mode keeps working.

## Sizes

| Name | Mac | iPhone and iPad | What it is |
|---|---|---|---|
| `Theme.cardRadius` | 16 | 20 | A card's corners. |
| `Theme.tileRadius` | 12 | 16 | A tile's corners inside a card, concentric with it. |
| `Theme.cardInset` | 20 | 20 | Room inside a card. |
| `Theme.tileInset` | 4 | 4 | How far a tile sits inside its card. |
| `Theme.cardGap` | 12 | 12 | The gap between cards. |
| `Theme.dayTile`, `Theme.planMark` | 44, 26 | 44, 26 | The plan's grid: a day's tile, and the mark beside it. |
| `PadMetrics` | | iPad | The sidebar (318), its panel's corners (26), the page (700), the bar (44) … |
| `WindowMetrics` | Mac | | The window's top line (52), the sidebar (270). |

A radius by number is a sign that a part is missing (T5).

## Words

A menu item's words come from `Say` in `Sources/Causabee/MatterMenus.swift`, in Title Case, with "…" when it asks something more first (C5). The same action has the same words on every device ([../parity-checklist.md](../parity-checklist.md)).

## A new part

When none of these fits:

1. Say so in the feature's Looks (`4-ui-spec.md`, "Design system"): what it is, and why none fits.
2. Build it once, in the file of the table above that matches who uses it — both apps, the Mac, or the iPhone and the iPad.
3. Give it a `///` line that says what it is for, in the house's words.
4. Take its colours from [colors.md](colors.md) and its type from [typography.md](typography.md).
5. Add it to this file, in the same change.
