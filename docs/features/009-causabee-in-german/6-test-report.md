# F009 · Causabee in German — Proof

## Each criterion

Every row ran on 13 November 2026, on this Mac (`scripts/test.sh`) or in the simulator. One row per
criterion; what else was looked at by hand stands under the table.

| Criterion | Test | Result |
|---|---|---|
| AC-1 · Every word of the app is German | `GermanTests` "F009 AC-1 · Every word has German" — 347 shared words, 1,443 of the apps' and 20 of the share sheet's, none without German, none left "new" or "stale"; `EveryWordTests` "· No word a person reads escapes the catalogue" and "· Every word is looked up in its own catalogue"; `GermanAtRuntimeTests` — the compiled German side asked for every one of its keys | pass |
| AC-2 · A matter keeps its own language | `GermanTests` "F009 AC-2 · A matter keeps its own language" — the prompts still say to write in the content's language, their versions unchanged; `GermanAtRuntimeTests` "· What the bee wrote is not looked up"; and by hand on the Mac in German with the English demo | pass |
| AC-3 · Days as the device writes them | `DateLocaleTests` "F009 AC-3" (three tests) — no forced `en_US`/`en_GB` left in a path a person reads, the 18 `en_US_POSIX` still there, a German device reads German days; and by hand: "5 Mails · seit 23. Okt.", "HEUTE · FR. 13. NOV.", "Überfällig seit 12. Nov." | pass |
| AC-4 · One word for one thing | `GermanTests` "F009 AC-4 · One word for one thing" — no German word serves two English ones, no English one has two Germans, each catalogue on its own | pass |
| AC-5 · German fits | `GermanTests` "F009 AC-5 · German fits where the room is fixed" — the 21 words that sit in a place that cannot grow, against the room there is; and by hand on the iPhone, the iPad and the Mac, at the usual text size and the largest | pass |
| AC-6 · The owner can see German on an English device | `GermanBeyondTheAppTests` "F009 AC-6 · German can be picked for Causabee alone" — what makes the device offer it: `de` among the project's regions, a German side in the shared bundle beside the English, and no switch inside Causabee. The owner set Causabee alone to German on their own English iPhone and read it through: "iphone looks good", "german looks good" | pass |
| AC-7 · The App Store page in German | `GermanBeyondTheAppTests` "F009 AC-7 · The App Store page in German is written and fits" — `store-de.md`: all six fields, each inside Apple's limit, German, du, and more than mail named. Posting it in App Store Connect is a step of the release that makes the page, written down as one | pass |
| AC-8 · Nothing already there is rewritten | `GermanTests` "F009 AC-8 · Nothing already there is rewritten" — a matter, its brief and its next step read the same with the language changed | pass |
| AC-9 · English stays as it is | `GermanTests` "F009 AC-9 · English stays as it is" — no key carries an English value of its own, so the English a person reads is still the source's own word, and the eight words' suites are all there to read it. All 724 tests green | pass |
| AC-10 · German for whoever listens | `GermanTests` "F009 AC-10 · German for whoever listens" — every spoken word is in a catalogue with German | pass |
| AC-11 · Causabee says du | `GermanTests` "F009 AC-11 · Causabee says du" — no formal address in any German word, counting a sentence's first word as the word it is | pass |

**What was looked at by hand, beyond the tests.** The iPhone (iOS 27.2) and the Mac in German,
through the welcome, the overview with its week strip, a matter's Überblick, Plan and Dateien, and
the assistant: nothing cut off, no button without its words. The same iPhone at the largest text
size (accessibility XXXL): the title wraps over three lines, the NEU chip grows to two, German's long
words hyphenate, nothing is cut or overlapped. The iPad in German: the sidebar ("Übersicht", "0 heute
· 1 überfällig", "Anliegen"), a matter's page with its four tabs, the dated rows, the when-chips and
the counts.

**What is still only on paper.** The German App Store page exists as words, not as a page: Causabee
is not in the German store, and the first release is what makes it. AC-7 was changed to say so on
13 November, and the posting stands under "Left for the release" in this feature's README.

## Everything else still works

- **The unit tests:** 724 in 150 suites, all green (`scripts/test.sh`). 20 of them are F009's. One
  run while three simulators were building failed `SpeedTests` "What the screens work out,
  measured"; it passes on an idle machine, as it always has — it measures the Mac, not the code.
- **The screen tests:** `CausabeePhoneUITests` on the iPhone, 87 of them. A first run found two
  things this feature broke, and both are fixed:
  - `DigestNewUITests.testAPinnedCardSaysItsNextDayByItsCount` asked for "4 open · Nov 14" by a
    regular expression; this Mac's region is German, so the day reads "14. Nov.". It asks for a
    month and a number in either order now.
  - nine `ManifestoUITests` could not find a tab: they do not write `"part.Plan"`, they build it
    (`"part." + name`), so the rename to the part's own name missed them. `RegressionTests` and
    `ChatAddTests` looked a tab up by the word on it, which is the thing this feature changes.
  A second full run: **87 tests, 7 skipped, 1 failure** — `RegressionTests.testTheFilters`, which
  loops over `["Digest", "Mail", …]` and so was a third place building the handle out of a word.
  Reading for that shape turned up the same in `ScrollTests`, `PadTests` and both of the Mac's
  suites, which had not run yet; the Mac's two helpers looked a tab up by its label outright. All
  of them pass the part's own name now.
- **The iPhone, the four suites that look a tab up**, run again on the fixed tests: **35 tests, 0
  failures** (`RegressionTests` 7, `ManifestoUITests` 19, `ChatAddTests` 1, and the rest).
  `testTheFilters` is among them.
- **The Mac:** `CausabeeAppUITests`, **34 tests, 0 failures**, built after the two helpers were
  rewritten — the test binary holds `part.…` and no longer holds the label predicate.
- **The iPad:** `PadTests` on an iPad Pro 13-inch, **5 tests, 0 failures**, including
  `testOnItsSideThePageIsOneColumn`, which walks all six filters. Its binary holds the part names
  and no `part.Digest`.
- Nine of those test files were changed by this feature: a pill's accessibility identifier is the
  part's own name now ("part.plan", "overview.matters"), not the word on it, because the word is
  German on a German device and a test must find the same button in every language. The suites that
  have run so far cover that change (`AutoTests`, `ChatAddTests`, `GoodToKnowUITests`,
  `DigestNewUITests` apart from the day).
- **The net:** `python3 -I scripts/words.py --escaped` names nothing. `scripts/words-machine.txt`
  holds the 344 literals that are not words a person reads, each looked at once;
  `scripts/words-values.txt` the 409 keys only the compiler can name.
- **Not run:** a German VoiceOver pass by ear — the words are in the catalogue with German, which is
  what AC-10 asks, but nobody has listened yet.

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

Both builds went out on 13 November, on the owner's word ("both"):

- **TestFlight 0.5 (252)** for the iPhone and the iPad. The iPhone's regression tests, the iPad's
  tests and the iCloud Production schema check all passed before anything was uploaded.
- **Mac 0.5 Beta 135**, signed with the Developer ID, as a disk image in
  `~/Library/Caches/causabee-release/v0.5.0-beta.135/` — a dry run: nothing published to GitHub or
  the website. 724 unit tests and the Mac's 33 screen tests green first.

Read out of the shipped Mac app, not out of the repository: it carries `de.lproj` beside `en.lproj`,
which is what makes macOS offer Causabee in its per-app language list, and 1,792 German words in two
tables — 1,445 of the app's own ("Set day" → "Tag festlegen") and 347 shared ("Overdue since %@" →
"Überfällig seit %@", "Digest" → "Überblick"). The German welcome pictures are in `de.lproj`, the
English ones in `en.lproj`.

**The iPhone, 13 November.** The owner set Causabee alone to German on their own English iPhone —
Settings › Apps › Causabee › Language › Deutsch, build 0.5 (252) — and read it through: **"iphone
looks good"**, and then, on the German itself, **"german looks good"**. So the per-app language row
is there, the app comes up German on an English phone, and no word read wrong to the person who
asked for this. That is what AC-6 asks: its Given is the owner's own iPhone, iPad **or** Mac.

Two things were not separately reported, and are not claimed here: switching the phone back to
English, and the Mac and the iPad. Beta 135 is built and signed and in the owner's hands, and the
iPad has the same TestFlight build as the iPhone, if either is ever wanted.

**What the owner found while reading.** Not a German fault, and not built: on one of their own
matters the card says "9 offen · 4 für dich · wartet auf 5" and the Plan shows four things. A task
someone else owes whose day has gone by lands in `Journal.Plan.noAnswer`, which is counted in
`plan.openCount` and in the card's `waiting`, but drawn only by the Überblick's card — the Plan
never draws it. It counts and hides the same in English. Parked in `docs/backlog.md` with its file
and lines, and what has to be decided: whether the Plan gets its own "Noch keine Antwort" section,
or whether `openCount` stops counting what the Plan does not show.

