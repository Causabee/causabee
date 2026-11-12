# UI check · F007 Plan and usage, the same on every device · 12 November 2026

Scope: branch `feature/007-plan-and-usage-the-same-on-every-device` since main — `PlanUsageRows`, `UseProToggle`, `PlanSettings` (the page) and `ProBar` in `Sources/Causabee/PlanSheet.swift` and `BeeServer.swift`; the iPhone's and iPad's `SettingsSheet`; the Mac's `ModelSettingsView` panes; the bees' and the chat's words · rules: docs/design-system.md

| Question | Verdict |
|---|---|
| Apple's HIG | pass |
| Causabee's tokens | pass |
| Reuses the components | pass |
| Built on Liquid Glass | pass — nothing new floats; Settings stays a grouped `Form` |

## Findings

None.

- **H1, H3 the system's controls:** the row is a `NavigationLink` in the form, the switch a `Toggle`, the Mac's panes a `TabView` in the `Settings` scene with `Label`s — Apple's Settings window with panes.
- **H4 text that grows:** the row's line wraps under its title (seen in the simulator: "… · not / in use"); the thin bar stays under it.
- **H6 VoiceOver:** the row reads as one element; each bar says "not in use" or "not counted yet" (`PlanWordsTests` AC-3, AC-4); the bees say "Using Pro", "Not using Pro".
- **H10 dark mode:** the greyed bar is `Theme.strongLine`, which adapts; "not in use" is said in words as well.
- **T2 meaning:** yellow and gold stay the month's and the top-ups'; grey for not in use — `Theme.strongLine`, its new use written into `docs/design-system/colors.md`; orange only for running low.
- **T4 the same set the same way:** one `PlanSettings` page on every device; one `UseProToggle` in Settings and on the page; one `PlanWords` for every word.
- **C3 reuse:** the page reuses F006's `ProBar`; the row's 4-point bar is drawn in place — a smaller cousin of `ProBar`'s, not a new component.

Seen in the iPhone 18 Pro simulator with the demo's plan pictures: Settings with the row and "Use Pro" on top and Mail in view (Pro, top-ups, Free), the page for Free and for top-ups after Pro ended, "Use Pro" on and off. The Mac's panes not pictured — a window picture brings up macOS's screen-recording dialog; the Mac's screen tests open Settings.

## Kept on purpose

None.

## Mechanical check

## Mechanical check — lines changed since fbe1d07

0 ✗ · 0 ? · rules in docs/design-system.md

Verdict: pass
