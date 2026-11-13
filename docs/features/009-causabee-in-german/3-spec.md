# F009 · Causabee in German — How

## Data

Nothing is stored, nothing is synced, nothing is sent. The language is the device's, read by the system; Causabee keeps no setting of its own (AC-1, AC-6).

**Two String Catalogues, each where its words live:**

- `Sources/MatterCore/Resources/Localizable.xcstrings` — the words shared by all three devices: `Welcome`, `ProMeter`, `GoodToKnow`, `DeviceTask`, `Digests`, `ScreenshotDoor`'s bylines, the plain words of an error (`plainWords`). Package.swift gets `defaultLocalization: "en"` and MatterCore `resources: [.process("Resources")]`. Tried on 13 November: `swift build` compiles it to `en.lproj` and `de.lproj` in `MatterCore_MatterCore.bundle`, and `String(localized:bundle: .module)` reads it — so the same words serve the Xcode apps and `swift build` alike.
- `App/Resources/Localizable.xcstrings` — the apps' own words, for the Mac, the iPhone and the iPad and the share extension. `App/Resources` is a file-system synchronized group in the project, so the catalogue is part of all three targets by being in the folder. Xcode fills it from every `Text("…")`, `Label("…")`, `Button("…")`, `.accessibilityLabel("…")` and alert in the app sources by itself.
- The project's `knownRegions` gains `de`.

**The words that are already keys (413):** 288 `Text("…")` and 125 with a value in them need no change at all — SwiftUI looks up the English words as the key. Only the German side is written.

**The words that are built as Strings (301, mostly MatterCore):** their type stays `String`, so every test that compares them keeps passing (AC-9). Each becomes a looked-up word with the English text as both key and fallback:

```swift
// was: public static let privacy = "Names are disguised before anything is sent."
public static var privacy: String {
    String(localized: "Names are disguised before anything is sent.", bundle: .module)
}
```

**Words that read the same in English but mean two things** (an "Open" that opens, an "Open" that is still open) get a comment in the catalogue, which makes them two entries; without one they would share a German word and AC-4 would be wrong in the other direction.

**`Say`** (`MatterMenus.swift`, 28 menu words) is the Mac's own file and uses `Bundle.main`; the design system's rule C5 stays as it is — the words still come from `Say`.

Schema change: none

## Sync and other devices

- Nothing about the language syncs: each device follows itself. One person can read German on the iPhone and English on the Mac, and the same matter is the same matter.
- **An older build** on another device shows English, as today. Nothing it reads or writes changes: the catalogue is in the app bundle, never in the store, and no stored word changes (AC-8).
- Matters, notes, briefs, tasks and dates are never rewritten or read again when the language changes (AC-8): the bee's words are stored as they were written, and only the frame around them is looked up anew.

## Privacy

Nothing new leaves the device. The catalogue is in the app bundle. The prompts do not change, so nothing more and nothing less is sent than today.

## The AI

No prompt changes, no new version: `ExtractionPrompt` stays `extract-v18` and `DeviceReader` `device-2`. Both already say to write in the language of what was read (AC-2), and the chat keeps `AssistantAsk.language`, which answers in the question's language. The bee's words about a matter are therefore untouched by this feature.

**The German words themselves are written by hand, not by the reader's AI:** Claude writes them into the catalogue in the house's rules, and the owner reads every line before the Build gate.

## Calendar and Reminders

What Causabee writes into a Calendar event or a Reminder is the matter's own words, as today — it is content, not the app's frame, so it stays in the matter's language (AC-2). Only Causabee's own labels around them follow the device.

## Dates and numbers

- **The 20 places that force English for something a person reads** — `Locale(identifier: "en_US")` and `en_GB` in `Theme.swift`, `OverviewWeek.swift`, `Journal.swift`, `AssistantView.swift`, `MatterStatusView.swift`, `WeekStrip.swift`, `OverviewScreen.swift`, `MatterScreen.swift`, `AssistantSheet.swift`, `ProMeter.swift`, `ShareViewController.swift` — drop the forced locale and take the device's (AC-3). The `.environment(\.locale, …)` lines in `MatterStatusView` and `MatterScreen` are for pictures and go the same way.
- **The 18 `en_US_POSIX` places stay exactly as they are:** `EMLParser` (a mail's own date), `DeviceReader` (the date given to Apple's model), `GoldenSet`, `ScreenshotDoor` and the store's own keys. These are read by machines; a German month name there would change what is parsed or sent.
- Numbers and shares take the device's locale too, and prices already come from the App Store in the right one.

## When it fails

- **A word has no German yet:** the catalogue falls back to the English source word — the app still works, and the test of AC-1 fails until it is written, so it cannot ship.
- **A German word does not fit** (AC-5): it is rewritten shorter, not squeezed; the screen tests on a German device and the owner's own look are what find it.
- **The device is in a language that is neither:** English, as today (AC-9).
- **The language changes while the app runs:** iOS and macOS restart the app when a person changes its language, so nothing has to be reloaded by hand.
- **A string built from pieces in code** ("3 " + "matters") cannot be translated as one: each such place becomes one word with a value in it, so German can put the pieces in its own order.

## Trying it (AC-6)

The owner's devices are English. German is seen without changing them:

- **iPhone and iPad:** Settings → Causabee → Sprache → Deutsch. The row exists as soon as the app ships two languages.
- **Mac:** System Settings → General → Language & Region → Applications → Causabee → Deutsch.
- **In the simulator and in tests:** the scheme's language, or `-AppleLanguages (de)` as a launch argument, which the screen tests use.

## Where in the code

**Shared (MatterCore):**
- `Package.swift`: `defaultLocalization: "en"`, MatterCore `resources: [.process("Resources")]`.
- `Sources/MatterCore/Resources/Localizable.xcstrings` (new): the shared words, English and German.
- `Model/Welcome.swift`, `Model/ProMeter.swift`, `Model/GoodToKnow.swift`, `Model/DeviceTask.swift`, `Digests.swift`, `Screenshot/ScreenshotDoor.swift`, `Claude.swift` (`plainWords`): each word becomes `String(localized:bundle: .module)`.

**The apps:**
- `App/Resources/Localizable.xcstrings` (new): the apps' own words; Xcode fills the English side from the sources.
- `App/Causabee.xcodeproj/project.pbxproj`: `knownRegions` gains `de`.
- `Sources/Causabee/MatterMenus.swift` (`Say`), `CardActions.swift` (the notifications), `PlanSheet.swift`, `Theme.swift`: their built words looked up the same way, through `Bundle.main`.
- The 20 date places named above lose their forced locale.
- **The Mac's `swift build` binary** keeps English for its own words — its bundle has no catalogue — while MatterCore's are German. It is a development build, not what anyone ships; the Xcode app is the Mac app.

**Tests:**
- `GermanTests` (new, MatterCore): reads both catalogues and holds AC-1 — every key has a German word, none empty, none left in the state "new" or "stale"; and AC-4 — no German word is used for two different English ones, and no English one has two German words.
- `DateLocaleTests` (new): no `Locale(identifier: "en_US")` or `en_GB` is left in a path a person reads (source); `en_US_POSIX` is still in all 18 machine places.
- The words' tests stay as they are and must pass: `SaidAsItIsTests`, `PlanWordsTests`, `StoreCopyTests`, `OwnCopyTests`, `PlainWordsTests`, `WelcomeTests`, `ProMeterTests`, `ManifestoTests` (AC-9).
- Screen tests on a German device: the iPhone, the iPad and the Mac started with `-AppleLanguages (de)`, through the welcome and a matter — nothing English, nothing cut off (AC-1, AC-5).
