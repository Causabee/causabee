# F009 · Causabee in German — Proof

## Each criterion

| Criterion | Test | Result |
|---|---|---|
| AC-1 · Every word of the app is German | `GermanTests` "F009 AC-1 · Every word has German" — 347 shared words, 1,443 of the apps' and 20 of the share sheet's, none without German, none left "new" or "stale" | pass |
| AC-1 | `EveryWordTests` "F009 AC-1 · No word a person reads escapes the catalogue" — every string literal in the sources read as Swift reads it; each is a catalogue key or named in `scripts/words-machine.txt` | pass |
| AC-1 | `EveryWordTests` "F009 AC-1 · Every word is looked up in its own catalogue" — `bundle: .module` in MatterCore, never in the apps | pass |
| AC-1 | `GermanAtRuntimeTests` — the compiled German side of the bundle asked for every one of its keys: German comes back, not English, and a value lands where German puts it | pass |
| AC-2 · A matter keeps its own language | `GermanTests` "F009 AC-2" — the prompts still say to write in the content's language, their versions unchanged; `GermanAtRuntimeTests` "What the bee wrote is not looked up" | pass |
| AC-2 | By hand: the Mac in German with the English demo — every word of the app German, every word of the matters English, side by side | pass |
| AC-3 · Days as the device writes them | `DateLocaleTests` — no forced `en_US`/`en_GB` left in a path a person reads, the 18 `en_US_POSIX` still there, German days formatted German | pass |
| AC-3 | By hand: "5 Mails · seit 23. Okt.", "HEUTE · FR. 13. NOV.", "Überfällig seit 12. Nov." — the device's order, and one full stop, not two | pass |
| AC-4 · One word for one thing | `GermanTests` "F009 AC-4" — no German word serves two English ones, no English one has two Germans, each catalogue on its own | pass |
| AC-5 · German fits | By hand on the iPhone (iOS 27.2, German) and the Mac: the welcome, the overview with its week strip, a matter's Überblick, Plan and Dateien, the assistant. Nothing cut off, no button without its words | pass |
| AC-5 | The largest text size, and the iPad | not run |
| AC-6 · Causabee alone in German | By hand on the owner's own English device: the app set to German while the device stays English | not run — the owner's device |
| AC-7 · The App Store page in German | By hand in App Store Connect, with the release | not run — at release |
| AC-8 · Nothing already there is rewritten | `GermanTests` "F009 AC-8" — a matter, its brief and its next step read the same with the language changed | pass |
| AC-9 · The words' tests unchanged and green | `SaidAsItIsTests`, `PlanWordsTests`, `StoreCopyTests`, `OwnCopyTests`, `PlainWordsTests`, `WelcomeTests`, `ProMeterTests`, `ManifestoTests` — all green in the 720 | pass |
| AC-10 · German for whoever listens | `GermanTests` "F009 AC-10" — every spoken word is in a catalogue with German | pass |
| AC-11 · Causabee says du | `GermanTests` "F009 AC-11" — no formal address in any German word, counting a sentence's first word as the word it is | pass |

## Everything else still works

- **The unit tests:** 720 in 149 suites, all green (`scripts/test.sh`). 14 of them are F009's.
- **The screen tests:** `CausabeePhoneUITests` on the iPhone, 87 of them, were started and are
  still running as this is written. Of the first 20, one failed —
  `DigestNewUITests.testAPinnedCardSaysItsNextDayByItsCount`, which asked for "4 open · Nov 14" by
  a regular expression; this Mac's region is German, so the day reads "14. Nov.". It asks for a
  month and a number in either order now and has yet to be re-run. **The suite's result is not in
  this report yet.**
- Nine of those test files were changed by this feature: a pill's accessibility identifier is the
  part's own name now ("part.plan", "overview.matters"), not the word on it, because the word is
  German on a German device and a test must find the same button in every language. The suites that
  have run so far cover that change (`AutoTests`, `ChatAddTests`, `GoodToKnowUITests`,
  `DigestNewUITests` apart from the day).
- **The net:** `python3 -I scripts/words.py --escaped` names nothing. `scripts/words-machine.txt`
  holds the 344 literals that are not words a person reads, each looked at once;
  `scripts/words-values.txt` the 409 keys only the compiler can name.
- **Not run:** the Mac's and the iPad's screen tests; the largest text size; a German VoiceOver
  pass by ear (the words are in the catalogue, which is what AC-10 asks, but nobody listened yet).

## The AI's answers

No AI was asked anything new. The prompts are untouched, and their versions — `extract-v18`,
`device-2` — are what `GermanTests` "F009 AC-2" checks. What the bee writes about a matter stays in
that matter's language, which is the same instruction it had before this feature.

## What was built, and what was found while building it

The second wave — words the app puts together as it runs — was the whole of the work. Neither
SwiftUI nor the extractor can see them, so the sources were read literal by literal. Five of them
were not words at all but something the app read back out of a word, which German would have
broken:

- a file on its way here was known by its line beginning "Getting";
- a menu line cut the English "from the " off a sentence;
- whether a picture is a photo or a screenshot was read out of its byline;
- the pills' test handles were the words on the pills;
- the Mac's Matter menu was placed after a menu found by the title "Edit", which German macOS calls
  "Bearbeiten" — broken before this feature, and now fixed.

And one of my own making: `Source.ownWords` — the pointer "you", stored with every typed note and
compared on every device — had been looked up, so a German device would have matched nothing.

## The owner's own try

<!-- The build, the device, the date. What the owner did and saw, in their words. -->
