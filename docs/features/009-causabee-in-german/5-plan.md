# F009 · Causabee in German — Build

## Steps

1. **Tests first:** `GermanTests` and `DateLocaleTests` (MatterCore), seen failing — there is no catalogue and the forced locales are still there.
2. **The shared catalogue:** `defaultLocalization: "en"` in Package.swift, MatterCore `resources: [.process("Resources")]`, `Localizable.xcstrings` with the English side; every built word in MatterCore becomes `String(localized:bundle: .module)` — `Welcome`, `ProMeter`, `GoodToKnow`, `DeviceTask`, `Digests`, `ScreenshotDoor`, `plainWords`. The words' tests must stay green at every step: they compare the English, which is also the key.
3. **The apps' catalogue:** `App/Resources/Localizable.xcstrings`, `de` in `knownRegions`; Xcode fills the English side from the sources. The apps' own built words — `Say`, the notifications in `CardActions`, `PlanSheet`, `Theme` — looked up through `Bundle.main`.
4. **The dates:** the 20 display places drop their forced locale; the 18 `en_US_POSIX` stay, and the test says so.
5. **The German side,** written into both catalogues in the Looks's words and rules — du, short, no jargon, nouns capitalised. The words of the Looks's tables exactly as they stand there.
6. **Does it fit:** the iPhone, the iPad and the Mac in German (`-AppleLanguages (de)`), through the welcome, the first step, a matter and the plan, at the usual text size and the largest. A line that does not fit is rewritten shorter, in both languages' catalogues if it was English's fault too.
7. **Everything:** `scripts/test.sh`, the screen tests on the three devices in English and the welcome's in German, then `/ui-check 9`.
8. **The owner reads every German word** on their own device, before the gate.
9. **The App Store page in German** (AC-7): in App Store Connect, by hand, with the release — written here, posted when the release is prepared.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | `GermanTests` "F009 AC-1 · Every word has German" — both catalogues read: every key has a German value, none empty, none left "new" or "stale" | unit |
| AC-2 | `GermanTests` "F009 AC-2 · A matter keeps its own language" — the prompts still say to write in the content's language and their versions are unchanged (source); `AssistantAsk.language` untouched | unit |
| AC-3 | `DateLocaleTests` "F009 AC-3 · Dates as the device writes them" — no forced `en_US`/`en_GB` left in a path a person reads (source); the 18 `en_US_POSIX` places still there; `ProMeter.long` and `Dates` in German give German month names | unit |
| AC-4 | `GermanTests` "F009 AC-4 · One word for one thing" — no German word serves two different English ones, and no English one has two German ones | unit |
| AC-5 | The screen tests in German on the iPhone, the iPad and the Mac; the owner's own look at the largest text size | screen, by hand |
| AC-6 | By hand: Causabee set to German alone on the owner's English iPhone and Mac | by hand |
| AC-7 | By hand, in App Store Connect, with the release | by hand |
| AC-8 | `GermanTests` "F009 AC-8 · Nothing already there is rewritten" — a matter, its notes and its brief read the same with the language changed (a store built in English, read in German) | unit |
| AC-9 | The words' tests unchanged and green: `SaidAsItIsTests`, `PlanWordsTests`, `StoreCopyTests`, `OwnCopyTests`, `PlainWordsTests`, `WelcomeTests`, `ProMeterTests`, `ManifestoTests` | unit |
| AC-10 | `GermanTests` "F009 AC-10 · German for whoever listens" — every spoken word (`spoken`, `accessibilityLabel`) is in the catalogue with a German value | unit |
| AC-11 | `GermanTests` "F009 AC-11 · Causabee says du" — no "Sie", "Ihr", "Ihre" or "Ihnen" as an address in any German value | unit |

## The UI check

`/ui-check 9` after the code; its report `ui-check.md` in this folder, "Verdict: pass" before the gate. It reads the German screens as well as the English.

## What it adds to the manifesto

21. **The app speaks your language; a matter speaks its own.** Every word Causabee says of its own follows the device — its buttons, its lines, its dates. What the bee writes about a matter stays in that matter's language, so a German and an English matter sit side by side and each reads as it came in. Tested by `GermanTests` "F009 AC-1" and "F009 AC-2".

## The line for the release notes

- **Causabee spricht Deutsch:** on a German iPhone, iPad or Mac every word of the app is German, with its dates and numbers. Your matters keep their own language — a German one reads German, an English one English.
