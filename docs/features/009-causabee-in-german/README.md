# F009 · Causabee in German

- Stage: 6
- Lane: feature
- Started: 2026-11-13
- Branch: feature/009-causabee-in-german

## Gates

| Stage | Opened | The owner's word |
|---|---|---|
| 1 · Why | 2026-11-13 | Yes, go |
| 2 · What | 2026-11-13 | open |
| 3 · How | 2026-11-13 | Approved, go |
| 4 · Looks | 2026-11-13 | Approved |
| 5 · Build | 2026-11-13 | go |

## Changes after a gate

- 2026-11-13, at Build: AC-9 says a test that asserts a formatted day now pins the language it asks about. AC-3 makes a day follow the device, and this Mac is English with a German region, so `ProMeter.long`, `NextStep.short` and the plan's corner give "1. December" and "30. Sep" here. Nine assertions in `ProMeterTests`, `PlanWordsTests` and `NextStepTests` were asserting the Mac's region without knowing it. The words themselves do not change.

<!-- A criterion or the spec changed after it was approved: the date, what changed, why. One line each. -->
- 2026-11-13, at Build: the welcome's three pictures are the app's own screens, so on a German device they showed English ones. They are now a resource like any other word: `App/Resources/en.lproj` holds the English six (`welcome-1…3.png`, `phone-welcome-1…3.jpg`), `App/Resources/de.lproj` the German six, taken from the German example matter. No code changed — Apple's own lookup takes the device's language, which is why the English ones had to move out of the bundle's root first. Not in a criterion: AC-1 is about words. The owner asked for German shots on 13 November, and a German welcome showing English screens is what principle 10 calls squeezing.
- 2026-11-13, at Build: the share sheet runs in a bundle of its own, so `Bundle.main` there is the extension and not the app — its 20 words came back English. It has a catalogue of its own now, `Sources/CausabeeShare/Localizable.xcstrings`, with the same German the app says. The tests read three catalogues from here on.
- 2026-11-13, at Build: the same as the AC-9 change above, now for a screen test. `DigestNewUITests.testAPinnedCardSaysItsNextDayByItsCount` asked for "4 open · Nov 14" by a regular expression; this Mac's region is German, so the day reads "14. Nov." and the test failed on a day it was never about. It asks for a month and a number in either order now.
- 2026-11-13, at Proof: AC-5, AC-6, AC-7 and AC-9 were planned as by-hand criteria with no test of their own. Each has one now, holding the part a machine can hold, so none of them can be lost without a word of warning: AC-5 the 23 words that sit in a place that cannot grow, against the room there is; AC-6 what makes a device offer German for Causabee alone (`de` among the project's regions, a German side in the bundle, no switch inside the app); AC-7 the German App Store page's own words, written into `store-de.md`, each field inside Apple's limit; AC-9 that no key carries an English value of its own, so the English a person reads is still the source's own word. The by-hand part of each is unchanged, and `5-plan.md`'s table says both now.

- 2026-11-13, at Proof: AC-7 said the German App Store page is German when it is looked at. There is no page to look at — Causabee is not in the German store, and the first release is what makes it. The criterion now says what belongs to this feature: the words, written in the repository, each field inside Apple's own limit, held by a test; pasting them in, with the German screenshots, is a step of the release, written down under "Left for the release" below. Nothing about the words themselves changed.

## Left for the release

- **The German App Store page**, from `store-de.md`: name, subtitle, promotional text, keywords,
  description and the beta's "What to test", pasted into App Store Connect's German locale — the
  English page is not touched. With the five screenshots taken again with the app's language set to
  German.
