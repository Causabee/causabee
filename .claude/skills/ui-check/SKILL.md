---
name: ui-check
description: Check new or changed Causabee UI (SwiftUI in Sources/Causabee, Sources/CausabeePhone, Sources/CausabeeShare — Mac, iPhone, iPad) against docs/design-system.md — Apple's Human Interface Guidelines, Causabee's tokens, reuse of its components, Liquid Glass — and report file:line findings. Use at the end of a feature's Build stage, before committing a fix or polish that touches a view, when the owner says "/ui-check", or asks whether a screen follows the HIG, the design system or glass.
---

# /ui-check

The rules are `docs/design-system.md`. Read it first; every finding names one of its rules.

Arguments: none (this branch's changes since main, and what is not yet committed) · `--all` (every view; for an audit) · file paths (those files whole) · a feature number, e.g. `5` (its branch's changes, report into its folder).

This check reports. It does not fix, unless the owner asks for the fixes in the chat.

## 1 · The script

Run `scripts/ui-check.py` with the same arguments, and `--report` for Markdown. It flags what a machine can see: T1 colours, T3 fonts, C1 buttons, C2 hand-made cards, G2 raw glass, G3 materials; and asks to look at H1 tap gestures, H5 glyph sizes, T5 radii.

For each ✗, read the line in context:
- a real break → a finding;
- intended, for a reason the code shows (a bitmap filled for an export, a drawing for the film) → say so under "Kept on purpose", and suggest the `// ui-check: allow <rule> — why` comment. Never add that comment yourself without the owner's yes.

For each ?, decide: a finding, or nothing. Do not list a ? you judged fine one by one; count them.

## 2 · The reading

Read every changed view in full — the `body` and the parts it calls — not only the changed lines. Then ask, per rule marked *read* in the doc:

- **H — Apple's HIG.** Buttons (H1), targets (H2), the system's control first (H3), text that grows (H4), symbols (H5), VoiceOver (H6), keys and menus on the Mac and the iPad (H7), one sheet (H8), undo (H9), dark mode and contrast (H10). When unsure what the HIG says, look up the page (developer.apple.com/design/human-interface-guidelines/…) rather than guess, and cite it. Do not report again what `docs/hig-review/HIG-REVIEW.md` already lists, unless the change makes it worse.
- **T — tokens.** Each colour's meaning (T2: yellow only for what waits for the owner). The same thing set the same way (T4): compare the new text with its neighbours on the page and with the same element on the other devices — size, weight, colour, opacity.
- **C — components.** For each new `struct …: View`, modifier or style: does one in the files the doc lists already do this (C3)? `grep` for it. A shared view uses the names right on both apps (C4). Menu words from `Say` (C5).
- **G — glass.** What floats over content is on glass (G1); neighbours share a `GlassEffectContainer` (G4); no glass on a card (G5).

Check all three devices: a view in `Sources/Causabee` built for both apps, `#if os(iOS)` branches, the iPad's layout in `Pad.swift` and `PadMetrics`.

## 3 · The report

Write it in the house's words: short sentences, never mail-only.

```
# UI check · <what was checked> · <date>

Scope: <branch, commit range or files> · rules: docs/design-system.md

| Question | Verdict |
|---|---|
| Apple's HIG | pass / n findings |
| Causabee's tokens | … |
| Reuses the components | … |
| Built on Liquid Glass | … |

## Findings
| Where | Rule | What | Use instead |
|---|---|---|---|
| `Sources/…/File.swift:123` | C2 | … | `.phoneCard()` |

## Kept on purpose
<the line, the rule, why — and the allow comment it would carry>

## Mechanical check
<scripts/ui-check.py --report, as it printed>

Verdict: pass | open
```

**Verdict: pass** only when no ✗ and no finding is left: each fixed, or kept on purpose with the owner's yes. Otherwise **Verdict: open**.

Where it goes:
- In a feature: `docs/features/NNN-name/ui-check.md`. `scripts/feature.py check 5` keeps the Build gate shut without it, or while it says "open".
- A fix or polish: in the chat, before the commit; the findings it does not fix are parked (`scripts/feature.py park "…"`) with their file:line.
- `--all`: `docs/ui-check/YYYY-MM-DD.md`.

Then say in two or three sentences what stands out, and stop. The owner decides what is fixed.

## While building

A hook (`.claude/settings.json`) runs the script after every edit to a Swift file in the app's views and tells you what the edit's lines break. Fix it in the same edit with the design system's part — or, if the owner wants it as it is, the allow comment with the why. Do not fix old lines the edit did not touch: park them.
