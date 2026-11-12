# UI check · F008 The welcome page · 12 November 2026

Scope: branch `feature/008-the-welcome-page`, ac16a07..HEAD — `Sources/Causabee/FirstStep.swift`, `NameLine.swift`, `IntroView.swift`, `CausabeeApp.swift`, `AssistantView.swift`, `MatterStatusView.swift`; `Sources/CausabeePhone/Welcome.swift`, `OverviewScreen.swift`, `MatterScreen.swift`, `PhoneShots.swift` · rules: docs/design-system.md

| Question | Verdict |
|---|---|
| Apple's HIG | pass — one finding, fixed |
| Causabee's tokens | pass |
| Reuses the components | pass — two findings, fixed |
| Built on Liquid Glass | pass |

## Findings

| Where | Rule | What | Use instead | Done |
|---|---|---|---|---|
| `Sources/CausabeePhone/Welcome.swift` (privacy line) | C2 | a grey box made by hand | `.phoneBox()` | fixed |
| `Sources/Causabee/IntroView.swift` (privacy line) | C2 | a grey box made by hand | `.quietBox(radius: 8)` | fixed |
| `Sources/Causabee/FirstStep.swift` (the demo's link) | H2 | a gold link in a line, under 44 points on touch | `.frame(minHeight: 44)` on iOS | fixed |
| `Sources/Causabee/NameLine.swift` | C3 | padded twice: `.padding` before `.phoneBox()`, which pads | `.phoneBox()` alone | fixed, seen in the simulator |

Read and found right:
- **H1:** every action is a `Button` — Send, Photo, Scan, File, Add a file …, the demo, Yes, Change, Save, Set up, Not now. **H4:** the column scrolls; Photo / Scan / File stack under large type (`ViewThatFits`). **H6:** the field is named "What’s on your mind?", Send "Send", the add buttons "Add a photo", "Scan a document", "Add a file"; the welcome's pictures are hidden, their words read. **H8:** the welcome is the one sheet; nothing opens over it. **H10:** tokens only, dark values with them.
- **T2:** yellow only where it was — the send button, the welcome's example chip; the mail card and the name box are grey. **T4:** the first step's title is `Theme.titleFont` on every device; the welcome's words come from one `Welcome`.
- **C3, C4:** `FirstStep`, `NameLine`, `MailOffer` are made of the parts that exist (`BeeMark`, `SendGlyph`, `.glassBehind`, `.quietButton()`, `.filledButton()`, `.buttonStyle(.gold)`, `.phoneBox()`, `.quietBox()`, `.phoneCard()`, `.journalCard()`) and shared by both apps; the iPhone's pickers are the chat's own `AttachButton`.
- **G1:** the field floats on glass, as the chat's. **G5:** no glass on a card.

## Kept on purpose

- `Sources/Causabee/FirstStep.swift` — `.glassBehind(RoundedRectangle(cornerRadius: 24))` (T5, a "to look at"): the chat's own field has this radius (`Conversation.swift`, `AssistantSheet.swift`), and the first step's field is meant to be that field. No allow comment added; the owner may ask for one.

## Mechanical check — lines changed since ac16a07

0 ✗ · 1 ? · rules in docs/design-system.md

### To look at (T5 1)

| Where | Rule | What | Line |
|---|---|---|---|
| `Sources/Causabee/FirstStep.swift:117` | T5 | a radius by number: Theme.cardRadius, .tileRadius, or a named one | `.glassBehind(RoundedRectangle(cornerRadius: 24))` |

Verdict: pass
