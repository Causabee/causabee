# UI check · F009 · Causabee in German · 13 November 2026

Scope: `feature/009-causabee-in-german`, 48 changed views in `Sources/Causabee`, `Sources/CausabeePhone`
and `Sources/CausabeeShare` · rules: docs/design-system.md

| Question | Verdict |
|---|---|
| Apple's HIG | pass |
| Causabee's tokens | pass |
| Reuses the components | pass |
| Built on Liquid Glass | pass |

## Findings

None.

This feature changes words, not screens: no view gained a colour, a font, a surface or a glass of
its own, and no `struct … : View` was added. What did change is of three kinds, and each was read:

- **A word is looked up where it was written.** `Text("Save")` became nothing — SwiftUI looks its own
  words up — and a word built in code became `String(localized: "…")`, which returns the same
  `String` the line had before. No view's shape depends on it.
- **A word with a value in it** became `String(format: String(localized: "Overdue since %@"), day)`.
  Same type, same place, one line longer.
- **A word that is also stored or compared** was split: the stored side stays English and the shown
  side is looked up from it (`InHand.word`, `RuleReason.word`, `JournalItem.kindWord`,
  `AtHandCard.word`, `ProposalRow.words(inEnglish:)`). Each of those draws with the part it drew
  with before.

Three small things did change behaviour, and each keeps the rules it touches:

| Where | Rule | What | Kept |
|---|---|---|---|
| `Sources/Causabee/Theme.swift` · `Fetching` | C3 | A file on its way here, or why it could not be got, is now a kind rather than a line known by its first word. `DocumentRow` and `FileFace` draw it as before — quiet with a spinner, or `Theme.warning`. | T2: the warning colour still means only a failure |
| `Sources/Causabee/Journal.swift` · `JournalPills` | C3, H6 | A pill carries a `handle` for its accessibility identifier, so a test finds it by the part's own name. The pill itself is unchanged. | H6: the label a person hears is still the word on the pill |
| `Sources/Causabee/OverviewWeek.swift`, `WeekStrip.swift`, `MatterCore/Journal.swift` | T4 | Three display formatters take a template instead of a fixed pattern, so a day is written in the device's order. Same font, same place. | T4: the day beside it is set the same way |

## Kept on purpose

Nothing new. No `// ui-check: allow` comment was added.

## Checked on the three devices

- **iPhone** (iPhone 18 Pro, iOS 27.2, German): the welcome, the overview with its week strip, a
  matter's Überblick, Plan and Dateien, the assistant with a question and its answer. German's
  longer words fit: the four tabs, the seven weekday letters, the three when-chips, the three
  buttons under the next step.
- **Mac** (German): the overview with the sidebar, a matter's page with the assistant beside it.
- **iPad**: `Pad.swift` and `PadMetrics` are untouched; its sidebar words are the overview's, which
  were read on the Mac and the iPhone.

## Mechanical check

```
## Mechanical check — the files named

0 ✗ · 0 ? · rules in docs/design-system.md
```

Verdict: pass
