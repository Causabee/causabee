# Causabee's design system — the rules a screen is checked against

Every new or changed screen on the Mac, the iPhone and the iPad keeps these rules. `/ui-check` measures a change against them; `scripts/ui-check.py` checks the ones a machine can. The rules are numbered so a finding can name one.

Four parts, as the check asks four questions:

1. **H** — does it follow Apple's Human Interface Guidelines?
2. **T** — does it use Causabee's tokens: its colours, its type, its sizes?
3. **C** — does it reuse Causabee's components, instead of a new one-off view or style?
4. **G** — is it built on Liquid Glass, as the rest of the app is?

Each rule says how it is checked: **script** (`scripts/ui-check.py` flags it), **read** (the `/ui-check` skill reads the code for it), or both.

Where the tokens and components live:

| File | Holds |
|---|---|
| `Sources/Causabee/Theme.swift` | Colours, serif fonts, `.onGlass` and `.glassBehind`, the buttons, `.box()` and `.quietBox()`, `SectionHeader`, `BeeChip`, `CardFace`, `MatterIconTile` |
| `Sources/Causabee/Journal.swift` | The matter page: `.journalCard()`, `.outlinedCard()`, `.journalRows()`, `.waitingTile()`, `.waitingRows()`, `.planRow()`, `.planDate()`, `NextCard`, `DayTile`, `JournalPills`, `WhenChips`, `ProLine`, `UpdateNowButton`; the radii and gaps (`Theme.cardRadius`, `tileRadius`, `cardGap`, `cardInset`, `tileInset`) |
| `Sources/Causabee/Components.swift` | The Mac's parts: `Card`, `RowDivider`, `MoreMenu`, `.rowIcon`, `SourceLink`, `CornerBee`, `.cardField()`, `.sidebarRow` |
| `Sources/CausabeePhone/Parts.swift` | The iPhone's and the iPad's parts: the title fonts, `.phoneBox()`, `.phoneCard()`, `PhoneEmptyBox`, `AssistantButton`, `PhoneMatterCard` |
| `Sources/Causabee/TextSize.swift` | The Mac's text styles, a fifth larger than the system's |
| `Sources/Causabee/MatterMenus.swift` | `Say`: the words of every menu item |

A new shared part goes into one of these files, with a `///` line that says what it is for.

How to use them, token by token and part by part:

- [design-system/colors.md](design-system/colors.md) — every colour token, its light and dark value, what it means, what may stand on what.
- [design-system/typography.md](design-system/typography.md) — the serif and the system's text styles, their sizes on each device, one style per role.
- [design-system/components.md](design-system/components.md) — which part to use for what: surfaces, buttons, labels, the matter page, the chat, glass, sizes.

These rules are what is checked; the three guides say how to keep them. A new token or part goes into its guide in the same change.

## H · Apple's Human Interface Guidelines

The reference is Apple's HIG (developer.apple.com/design/human-interface-guidelines). The review of 9 October (`docs/hig-review/HIG-REVIEW.md`) lists what the app already owes; a change does not add to it.

- **H1 · What is pressed is a button.** A `Button`, `Toggle`, `Menu`, `Link` or `NavigationLink` — not `.onTapGesture`. A button has a pressed state, takes the keyboard and is read by VoiceOver. *script, read*
- **H2 · A target is big enough.** 44 × 44 pt on the iPhone and the iPad; on the Mac at least the size of the system's small controls. A small glyph gets a larger `contentShape`. *read*
- **H3 · The system's control first.** `Toggle`, `Picker`, `DatePicker`, `Menu`, `.searchable`, `.confirmationDialog`, a sheet with × and ✓ in its bar. A hand-built one only where the system's cannot do it, with a comment that says why. *read*
- **H4 · Text grows with the reader's size.** Dynamic Type on the iPhone and the iPad; Causabee's scale on the Mac. No fixed point size on text (see T3). *script, read*
- **H5 · SF Symbols for icons.** Sized by the text style beside them or `.imageScale`, not by a point size. *script, read*
- **H6 · VoiceOver can say it.** A button with only an icon has a label; a picture that only decorates is hidden from it. *read*
- **H7 · Keys on the Mac and the iPad.** An action used often is also in the menu bar, with a shortcut where it is frequent. Esc cancels (`.cancelAction`), Return does the default (`.defaultAction`). *read*
- **H8 · One sheet at a time.** A sheet does not open another sheet over itself; it pushes, or closes first. *read*
- **H9 · Undo before asking.** What is removed by hand can be undone; a confirmation only for what cannot. *read*
- **H10 · Dark mode and contrast.** Every colour adapts (see T1); text on yellow and on gold stays readable in both. *read*

## T · Tokens

- **T1 · Colours come from `Theme`, or from the system's meaning.** `Theme.ink`, `.card`, `.box`, `.page`, `.line`, `.bee`, `.gold`, `.warning` … or `.primary`, `.secondary`, `.tertiary`, `Color.secondary.opacity(…)`. Never `Color(red:…)`, a hex value, `#colorLiteral`, or a named colour such as `.black`, `.white`, `.red`: they do not adapt to dark mode and are not ours. *script*
- **T2 · Each colour has one meaning.** Yellow (`Theme.bee`, `.waitingTile()`) means something waits for the owner — never decoration. Orange (`Theme.warning`) is overdue. Gold (`Theme.gold`) is a link. Grey (`Theme.done`) is done or waiting on someone else. *read*
- **T3 · Type comes from `Theme`, or from the system's text styles.** The serif only through `Theme.titleFont`, `.cardTitleFont`, `.rowTitleFont`, `.planNumberFont`, `.phoneTitleFont`, `.padTitleFont`, `.phoneCardTitleFont`. Everything else `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption` … with a weight if needed. No `Font.custom` outside `Theme.swift` and `Parts.swift`; no `.font(.system(size:))` on text. On the Mac the text styles are already Causabee's size (`TextSize.swift`). *script*
- **T4 · The same thing is set the same way, everywhere.** A heading, a reason, a step is in the same style as its kind elsewhere on the page and on the other devices. Text that stands beside a card is set as that card's text is (11 November: Summary and Good to know were smaller and dimmer than the Next card above them). *read*
- **T5 · Sizes come from `Theme`.** Radii and gaps: `Theme.cardRadius`, `.tileRadius`, `.cardGap`, `.cardInset`, `.tileInset`, `.dayTile`, `.planMark`; on the iPad `PadMetrics`. A new number only where none of these fits, and then once, as a name. *script (a hint), read*

## C · Components

- **C1 · The buttons there are.** `.filledButton()` for the one thing to do here, `.quietButton()` beside it, `.buttonStyle(.gold)` for a link in a line, `.buttonStyle(.plain)` for an icon or a whole row, `.rowIcon` for a small tool at the end of a row; on the iPhone also `.phone` and `.phoneFilled`. Never `.borderedProminent` (black words on black). No new `ButtonStyle`. *script, read*
- **C2 · The surfaces there are.** On the matter page `.journalCard()` and `.journalRows()`, `.waitingTile()` for what waits for the owner, `.waitingRows()` for what others must do. Elsewhere `.box()` and `.quietBox()` on the Mac, `.phoneBox()` and `.phoneCard()` on the iPhone, `Card` for rows in a box, `PhoneEmptyBox` for a section with nothing in it. Not a hand-made `.background(Theme.card, in: RoundedRectangle(…))`. *script, read*
- **C3 · A part that exists is used.** `SectionHeader`, `BeeChip`, `MoreMenu`, `RowDivider`, `SourceLink`, `NextCard`, `ProLine`, `UpdateNowButton`, `DayTile`, `JournalPills`, `WhenChips`, `CardFace`, `MatterIconTile`. A view that looks like one of these is one of these. A new part that more than one screen needs goes into the files above. *read*
- **C4 · Both apps, one name.** A view the Mac and the iPhone share uses the names that are right on both (`.filledButton()`, not `InkButtonStyle()`); a device's own look stays behind that name. *read*
- **C5 · Words from `Say`.** A menu item's words come from `Say` in `MatterMenus.swift`, in Title Case, with "…" when it asks something more. *read*

## G · Liquid Glass

On macOS 26 and iOS 26 the controls float on the system's glass. The Mac still runs on macOS 15, so glass goes through the two helpers in `Theme.swift`, which fall back to a thin material there.

- **G1 · What floats over the content is on glass.** A bar, a capsule, a round button in a corner, the chat's field: `.onGlass(shape)` for a control, `.glassBehind(shape)` for a field whose words stay sharp. *read*
- **G2 · Glass through the helpers.** Not `.glassEffect(…)` by hand: on the Mac it has no fallback for macOS 15, and on the iPhone it skips the house's one look. Raw glass only inside a `GlassEffectContainer`, where a group needs it, with a comment. *script*
- **G3 · No material by hand.** `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`, `.thickMaterial`, `.bar` are what came before glass; the helpers carry them for macOS 15. *script*
- **G4 · Neighbours share one glass.** Glass shapes that stand close together — a pair of buttons, a row of pills — are in one `GlassEffectContainer`, so they read and move as one. *read*
- **G5 · Glass is for controls, not for content.** Cards, rows and the page stay on `Theme.card`, `.box`, `.page`; no glass on a card, no glass on glass. *read*

## What the script leaves alone

- The files that define the system (`Theme.swift`, `Journal.swift`, `Components.swift`, `Parts.swift`, `TextSize.swift`) for the rules they define.
- The drawings of the app for the film, the website and the introduction (`IntroOpener.swift`, `IntroShot.swift`, `ShotView.swift`, `PhoneShots.swift`): they paint a picture with fixed colours and sizes on purpose. A screen the owner uses is not a drawing.
- A line that carries `// ui-check: allow T1 — why`, or has it on the line above. The why is required; the owner sees it in the report.

## Changing a rule

A rule changes with the owner, in this file, in the same change as the code that needs it — as the manifesto does.
