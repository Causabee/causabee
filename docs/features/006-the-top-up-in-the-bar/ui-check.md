# UI check · F006 The top-up in the bar · 12 November 2026

Scope: branch `feature/006-the-top-up-in-the-bar` since main — `ProBar` in `Sources/Causabee/BeeServer.swift`, the top-up's words in `PlanSheet.swift`, `Theme.topUp` in `Theme.swift` · rules: docs/design-system.md

| Question | Verdict |
|---|---|
| Apple's HIG | pass |
| Causabee's tokens | pass |
| Reuses the components | pass |
| Built on Liquid Glass | pass — nothing floats; the plan stays in its grouped `Form` |

## Findings

None.

- **H4 text that grows:** the number keeps `Theme.planNumberFont` (relative to `.largeTitle`), the words `.subheadline`, the line and notes `.footnote`, as the one bar had; the words wrap under the number at large sizes, they are not cut.
- **H6 VoiceOver:** each bar is one element with its own label — "This month's Pro: 59 percent left", "Top-ups: 33 percent of a Pro month left" (`ProMeterTests` AC-8).
- **H10 dark mode and contrast:** `Theme.topUp` adapts (`#B38F00` light, `#CCA800` dark); no bar is told from the other by colour alone — each has its number and words.
- **T2 meaning:** yellow stays the month's, as before; the top-ups' gold is a new token with one use, written into `docs/design-system/colors.md`; orange only for running low, as before.
- **T4 the same set the same way:** both bars use the one `bar(_:)` — the same font, size, colour of words, height and spacing; on the Mac, the iPhone and the iPad the same view.
- **C3 reuse:** no new view type: `ProBar`'s meter, drawn once per bar; its arithmetic in `ProMeter` (MatterCore), shared by every device.

Seen on the iPhone 18 Pro and the iPad Air simulators with the demo's plan (`--plan-shot pro`, `--plan-shot low`): two bars with a top-up, one orange bar running low without one, "Add a top-up · $2.99". The Mac's Settings window not pictured: the same view, built and run by the Mac's screen tests.

## Kept on purpose

None.

## Mechanical check

## Mechanical check — lines changed since f5fe319

0 ✗ · 0 ? · rules in docs/design-system.md

Verdict: pass
