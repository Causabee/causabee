# F009 · Causabee in German — Build

## How a word gets into the catalogue

`scripts/words.py` reads the sources and keeps the two catalogues:

| | |
|---|---|
| `python3 -I scripts/words.py` | takes in what is new, keeps the German there is, drops a word no line shows any more |
| `--missing` | says which words have no German yet |
| `--only core` / `--only app` / `--only share` | one catalogue alone, while the others' files are in hand |
| `--list` | every word, English beside German, under the screen it is on — `words.md`, for the owner to read |
| `--prune` | drops a word no line shows any more; without it such a word is kept, so German is never lost to a file that is open for a minute |
| `--build <derived data>` | the words that carry a value in a SwiftUI part, whose placeholder only the compiler knows; they are written into `scripts/words-values.txt` so a run without a build keeps them |
| `--escaped` | every literal in the sources that reads like words a person is shown and is in no catalogue. `--write` accepts what is found into `scripts/words-machine.txt`, the list of what was looked at and is not a word |

Three kinds of word, and how each is found:

- **SwiftUI's own** — `Text("Save")` looks itself up; the script reads the key out of the source.
- **Ours** — `String(localized: "Save", bundle: .module)` in MatterCore, `String(localized: "Save")` in the apps, where `Bundle.main` is right.
- **Built out of pieces** — `String(format: String(localized: "Overdue since %@", bundle: .module), day)`. The key stays a plain literal, so the script sees it without a build, and the whole sentence can be said in German's own order. Never an interpolation inside a looked-up literal: the key would differ from what the app asks for, and the word would stay English without a word of warning.

## Steps

1. **Tests first:** `GermanTests` and `DateLocaleTests` (MatterCore), seen failing — there is no catalogue and the forced locales are still there.
2. **The shared catalogue:** `defaultLocalization: "en"` in Package.swift, MatterCore `resources: [.process("Resources")]`, `Localizable.xcstrings` with the English side; every built word in MatterCore becomes `String(localized:bundle: .module)` — `Welcome`, `ProMeter`, `GoodToKnow`, `DeviceTask`, `Digests`, `ScreenshotDoor`, `plainWords`. The words' tests must stay green at every step: they compare the English, which is also the key.
3. **The apps' catalogue:** `App/Resources/Localizable.xcstrings`, `de` in `knownRegions`; Xcode fills the English side from the sources. The apps' own built words — `Say`, the notifications in `CardActions`, `PlanSheet`, `Theme` — looked up through `Bundle.main`. **And the share sheet's own,** `Sources/CausabeeShare/Localizable.xcstrings`: an extension is its own bundle, so `Bundle.main` there is the extension and the app's words never reach it (found at Build, 13 November).
4. **The dates:** the 20 display places drop their forced locale; the 18 `en_US_POSIX` stay, and the test says so.
5. **The German side,** written into both catalogues in the Looks's words and rules — du, short, no jargon, nouns capitalised. The words of the Looks's tables exactly as they stand there.
6. **Does it fit:** the iPhone, the iPad and the Mac in German (`-AppleLanguages (de)`), through the welcome, the first step, a matter and the plan, at the usual text size and the largest. A line that does not fit is rewritten shorter, in both languages' catalogues if it was English's fault too.
7. **Everything:** `scripts/test.sh`, the screen tests on the three devices in English and the welcome's in German, then `/ui-check 9`.
8. **The owner reads every German word** on their own device, before the gate.
9. **The App Store page in German** (AC-7): its words written here, in `store-de.md`, with Apple's own limit on each field and a test that holds them; pasted into App Store Connect by hand when the release is prepared, with the screenshots taken again in German.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | `GermanTests` "F009 AC-1 · Every word has German" — both catalogues read: every key has a German value, none empty, none left "new" or "stale" | unit |
| AC-1 | `EveryWordTests` "F009 AC-1 · No word a person reads escapes the catalogue" — the sources read whole by `scripts/words.py --escaped`: every literal that reads like words a person is shown is a catalogue key, or named in `scripts/words-machine.txt` as something else | unit |
| AC-1 | `EveryWordTests` "F009 AC-1 · Every word is looked up in its own catalogue" — `bundle: .module` in MatterCore, never in the apps: the wrong bundle shows English and says nothing | unit |
| AC-2 | `GermanTests` "F009 AC-2 · A matter keeps its own language" — the prompts still say to write in the content's language and their versions are unchanged (source); `AssistantAsk.language` untouched | unit |
| AC-3 | `DateLocaleTests` "F009 AC-3 · Dates as the device writes them" — no forced `en_US`/`en_GB` left in a path a person reads (source); the 18 `en_US_POSIX` places still there; `ProMeter.long` and `Dates` in German give German month names | unit |
| AC-4 | `GermanTests` "F009 AC-4 · One word for one thing" — no German word serves two different English ones, and no English one has two German ones | unit |
| AC-5 | `GermanTests` "F009 AC-5 · German fits where the room is fixed" — the 21 words that sit in a place that cannot grow (a pill in a row of pills, a chip, a card's short button), against the room there is; plus the screen tests in German on the three devices and the owner's own look at the largest text size | unit, screen, by hand |
| AC-6 | `GermanBeyondTheAppTests` "F009 AC-6 · German can be picked for Causabee alone" — what makes a device offer it: `de` among the project's regions, a German side in the shared bundle beside the English, and no switch inside Causabee; plus, by hand, Causabee set to German alone on the owner's English iPhone and Mac | unit, by hand |
| AC-7 | `GermanBeyondTheAppTests` "F009 AC-7 · The App Store page in German is written and fits" — `store-de.md`, every field inside Apple's limit, German, du, more than mail named; plus, by hand, pasted into App Store Connect with the release | unit, by hand |
| AC-8 | `GermanTests` "F009 AC-8 · Nothing already there is rewritten" — a matter, its notes and its brief read the same with the language changed (a store built in English, read in German) | unit |
| AC-9 | `GermanTests` "F009 AC-9 · English stays as it is" — no key carries an English value of its own, so the English a person reads is still the source's own word, and the eight words' suites are all there to read it; the words' tests themselves unchanged and green: `SaidAsItIsTests`, `PlanWordsTests`, `StoreCopyTests`, `OwnCopyTests`, `PlainWordsTests`, `WelcomeTests`, `ProMeterTests`, `ManifestoTests` | unit |
| AC-10 | `GermanTests` "F009 AC-10 · German for whoever listens" — every spoken word (`spoken`, `accessibilityLabel`) is in the catalogue with a German value | unit |
| AC-11 | `GermanTests` "F009 AC-11 · Causabee says du" — no "Sie", "Ihr", "Ihre" or "Ihnen" as an address in any German value | unit |

## The UI check

`/ui-check 9` after the code; its report `ui-check.md` in this folder, "Verdict: pass" before the gate. It reads the German screens as well as the English.

## What it adds to the manifesto

21. **The app speaks your language; a matter speaks its own.** Every word Causabee says of its own follows the device — its buttons, its lines, its dates. What the bee writes about a matter stays in that matter's language, so a German and an English matter sit side by side and each reads as it came in. Tested by `GermanTests` "F009 AC-1" and "F009 AC-2".

## The line for the release notes

- **Causabee spricht Deutsch:** on a German iPhone, iPad or Mac every word of the app is German, with its dates and numbers. Your matters keep their own language — a German one reads German, an English one English.
