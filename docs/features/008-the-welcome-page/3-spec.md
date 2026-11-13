# F008 · The welcome page — How

## Data

- **The welcome's words:** one shared set in MatterCore, `Welcome` (new, `Sources/MatterCore/Model/Welcome.swift`): the promise, at most three pages (picture name, title, one line), the privacy line, the first step's words, the demo's line, the mail card's words, the name line. Both apps draw from it, so the words are the same everywhere (AC-11) and a test can hold them.
- **Typed words (AC-4):** made into a message as a screenshot's text is today (`ScreenshotDoor.look` builds an `Email` from it): id `typed:<hash>`, subject the first line, body the whole text, from the owner, dated now. `MatterImport.apply` gives an id beginning `typed:` the kind `.conversation` — the owner's own word, a kind that exists today. So every task and date found leads back to the typed words, shown as the owner's.
- **The first matter:** `Matter.make` / `MatterImport.apply` as today. Its name is the bee's `matterTitle`, or the typed line (cut at 60 characters) when the bee gives none.
- **Your name (AC-12):** `Profile.names`, as the Mac's "About you" and the iPhone's Settings write it today. The line shows while `names` is empty. Saving makes the `Profile` if there is none, as `SetupAssistant.saveNames` does.
- **The mail card's "Not now" (AC-8):** `UserDefaults` key `mail.offer.later` on this device. The card shows only while `Keychain.accounts()` is empty (iCloud Keychain: a mailbox added on one device counts on all).
- **First start:** `intro.seen` as today. The Mac no longer opens `SetupAssistant` by itself: the chains at `CausabeeApp.swift:848-850` and `:885-887` go; `setup.later` stays read by nothing new.

- **The start credit (AC-14), on the beeserver — the app's store keeps nothing new:**
  - `POST /v1/start` (new): the app sends Apple's signed record of this download (`AppTransaction.shared`, its `jwsRepresentation`) and its account id (`Store.accountID`, the same that every purchase sends as `appAccountToken`, kept in the iCloud Keychain). The beeserver checks Apple's signature as it does a purchase's (`verifySigned`, `apple.ts`), the bundle id, and that this download is new enough (below). It makes the account `app:<id>` of kind `credit` if there is none — the one a later top-up or Pro lands in — and writes one ledger line of kind `grant`, `1_500_000` micros (one top-up, `topUps`), ref `start:<appTransactionId>`. The ref is unique, so the same Apple account never gets it twice, from any device or install. The answer brings the token, as a first top-up's does, and the allowance.
  - New enough: in the App Store's environment (`Production`), only when the download's `originalPurchaseDate` is on or after `START_CREDIT_FROM`, a date set on the beeserver when this build is released. TestFlight (`Sandbox`) has no such date: testers are the owner's choice.
  - `allowance` says `startCredit: true` while the account's extra is only that grant — no top-up bought — so the app names it "Start credit" (AC-15) and knows when it is used (AC-17).
  - The beeserver's database: one new value of an existing column (`ledger.kind = 'grant'` exists); no new table.
- **In the app:** `BeeServer.start()` (new) asks once, on the first start, when there is no beeserver token and the demo is not on; `UserDefaults` `start.asked` keeps it from asking again on this device. The card of AC-17: `UserDefaults` `start.used.later`.

Schema change: none

## Sync and other devices

- The matter, its tasks and dates, and the typed words' source sync through iCloud as anything that comes in does.
- The name syncs in `Profile.names`: answered on one device, the line is gone on every device once iCloud brings it (AC-12). The Mac syncs only with iCloud on (`CloudSync.mode`, off by default); without it, the Mac asks on its own.
- The mail card's "Not now" is per device: no synced field fits, and the schema stays. Setting up mail anywhere ends the card everywhere, through iCloud Keychain.
- **Already in use elsewhere (AC-10):** on a first start, signed in to iCloud and with nothing here yet, the overview waits for iCloud's first import (`PhoneCloudStatus`, `CloudSync`: an import event, at most 30 seconds, as `CloudCatchUp` waits on the Mac). Meanwhile the empty page says "Looking in iCloud for your matters …" above the first step. Matters or a `Profile` arrive: the overview shows them. Nothing arrives: the line goes and the first step stands alone. Signed out of iCloud, or the Mac with iCloud off: the first step at once.
- **The start credit** belongs to the beeserver's account, not to a device: every device with the same Apple account and iCloud Keychain uses the same account id, so the same credit, and none asks twice — a second device's `POST /v1/start` finds the ref and gets the token of the account that has it.
- **An older build** on another device sees an ordinary matter, and a source of kind `conversation`, which it knows. Its own welcome stays as it was. It still opens its own setup by itself, as before. It never asks for a start credit; with the account's token it uses one as it uses a top-up today.

## Privacy

- **With the start credit, Pro or a top-up left:** the first step's words and what is added are read through the beeserver, names, addresses and numbers disguised first (`Pseudonymizer`), as anything that comes in is with Pro. The privacy line on the first page says so once; the line under the first step says it is the start credit (AC-15). The rule of 13 November, the first words always on the device, goes (`Welcome.readsOnDevice`).
- **With nothing left:** read by Apple's model on this device. Nothing leaves it.
- **What the beeserver learns of the start credit:** the download's signed record — an id Apple gives this app for the Apple account, its dates and environment — and the app's account id. No name, no mail address, nothing typed. Kept: the ledger's ref `start:<appTransactionId>`.
- The name stays in iCloud as today, never sent except as part of what is disguised.
- No Contacts access: not asked, not used.

## The AI

Two prompts get a first-step paragraph, used only when there are no matters yet (`storeMatters` empty) — so nothing changes for anything that comes in later:

- the cloud reader's: `ExtractionPrompt` `extract-v17` → **`extract-v18`**;
- Apple's model's: `DeviceReader` `device-1` → **`device-2`**.

The paragraph: "This is the person's first matter. It is always a matter, never 'none'. Name it in one to three words, in the text's own language, from its own words — fix an obvious typo, never translate. Take each date's 'what' from the text's own words." The device's `isNew` is true then.

And a net in code, both readers (`Welcome.grounded`): a name or a date's "what" that shares no word with the typed line — after lowercasing, a typo's letters counted as close — is not used: the name falls to the line before its date, a date's "what" to the name. Two dates on the same day from one line are one.

**Pressure test, in Build, with made-up lines only:** the ten lines of 12 November and three with typos ("Der umzug ist für dne 1.2.2027 geplant", "Muttis Reha startet am 23.11.", "Steuererklrung bis 31. Juli"). Each must give a matter, a name in its own words and language, no invented date — with the cloud reader through the demo account, and with Apple's model on this Mac.

## Calendar and Reminders

Not touched. Dates and tasks found go on the matter; to Calendar and Reminders only with a tap, as today.

## When it fails

- **Apple's model not on this device, or busy:** the rules read it; the matter is made with the typed line as its name and the words kept. No error shown: it worked, less fully.
- **Reading fails** (an error, the beeserver not reached): the matter is still made with the typed line, the words kept, and one line on the matter: "Not read yet — your words are kept." It is read again on the next check, as a held mail is.
- **Pro is waiting** (`ProWait`, nothing left to use): Apple's model reads it, as without Pro.
- **No start credit given** — the beeserver not reached at the first start, Apple's record not to be had (no network, an Xcode build), a download from before `START_CREDIT_FROM`, the Apple account had one already, or a system older than iOS 18.4 / macOS 15.4 whose record has no `appTransactionId` to count it once by: nothing is said; the first step is read on the device, as with nothing left. The app asks once more at the next start while it has no token; then never.
- **The credit runs out in the middle of reading:** the beeserver's `allowance_used`, as with a top-up today: what was being read is read on the device, nothing lost; the card of AC-17 comes after.
- **A file Causabee cannot read:** as today — the card says so, nothing is made.
- **Nothing typed and Send tapped:** the button is off while the field is empty.
- **iCloud's first import never answers:** after 30 seconds the first step stands alone; matters that come later show as they come.
- **The name left empty:** the line stays on the first matter until answered; nothing else waits on it.

## Trying it (AC-14)

The owner, as a new person, as often as needed — never the App Store's once-per-account:

1. A TestFlight build (`Sandbox`): no date rule, so the owner's own Apple account gets the start credit at its first start of that build, if it has no beeserver account yet; a Sandbox tester account (App Store Connect → Users and Access → Sandbox) is a new person each time.
2. Again with the same account: `POST /admin/start-forget` with the account id takes back the account's start grant and its ref, in `Sandbox` only — the owner runs it with the admin secret; the app is reset with the Mac's `--fresh-setup`-like `--fresh-start` (forgets `start.asked` and the token on this device).
3. In the simulator and from Xcode, Apple's record is signed by Xcode, not by Apple: the beeserver refuses it, and the start credit is not given — the first step is read on the device. The beeserver's own tests check `/v1/start` with a test root, as `apple.test.ts` does for purchases.

## Where in the code

**Shared (MatterCore):**
- `Welcome.swift` (new): the words and pages.
- `MatterImport.swift`: id `typed:` → `.conversation`.
- `TypedDoor` (new, beside `ScreenshotDoor`): typed text → `Email` → `Spike` → `Judgement`, with `onDevice` as `ModelChoice.mailReader` says.

**Both apps:**
- `FirstStep` (new view, `Sources/Causabee/FirstStep.swift`, built for both): the field ("What's on your mind?"), Send, and the way to add — on the iPhone and iPad the existing `AttachButton` (photo, camera, scan, files), on the Mac `chooseScreenshot`'s open panel and the window's drop; the demo's quiet line under it. With no matters, what is added is taken into a new matter at once — the card that asks which matter is skipped, there being none — named as the bee proposes, and opened (`Conversation.take`, `PhoneShots.take`).
- `NameLine` (new, built for both): on a matter's page while `Profile.names` is empty. The Mac fills in `NSFullUserName()`. The iPhone and iPad start with an empty field — iOS has no "my card" (see the change to AC-12).
- `MailOffer` (new, built for both): the quiet card under the matters.

**Mac:**
- `IntroView.swift`: the pages from `Welcome`, at most three pictures.
- `CausabeeApp.swift`: the empty overlay (`:936-941`) becomes `FirstStep`; the setup's automatic opening (`:848-850`, `:885-887`) goes; Set Up Causabee … stays in the menu.
- `SetupAssistant.swift`: Hint 4's "or a note" made true by the first step; `isMissingSomething` no longer opens anything.

**iPhone and iPad:**
- `Welcome.swift`: the pages from `Welcome`; the last page's iCloud / Plan / Mail checks go; it ends with "Start".
- `OverviewScreen.swift`: `empty` (`:465-477`) becomes `FirstStep`, with the iCloud line of AC-10; the iPad uses the same.
- `SettingsSheet.swift`: the name field stays, as the place to change it.

**The start credit:**
- `server/beeserver/src/index.ts`: `POST /v1/start`, `/admin/start-forget`, `allowance`'s `startCredit`; `START_CREDIT_FROM` in `wrangler.toml`. Tests: `server/beeserver/test/start.test.ts` (new).
- `Sources/Causabee/BeeServer.swift` (both apps): `start()`, `startCredit`; asked from both apps' first start.
- `Sources/Causabee/FirstStep.swift`: the line of AC-15; `StartCreditUsed`, the card of AC-17, beside `MailOffer`.
- `Sources/MatterCore/Model/Welcome.swift`: the words; `grounded`; `readsOnDevice` goes.
- `Sources/MatterCore/Prompts/ExtractionPrompt.swift` (`extract-v18`), `Sources/MatterCore/DeviceReader.swift` (`device-2`): the first-step paragraph.
- The plan's page and Settings (`ProMeter`): the top-ups' bar named "Start credit" while `startCredit`.

**Pictures:** the Mac's from `scripts/intro-shots.sh` on the demo, at most three, chosen at Looks; the iPhone's in the simulator, as `ec2461f` made them. Lighter shots may need a demo `--shot` of their own (`IntroShot`).

**Tests:**
- `WelcomeTests` (new, MatterCore): AC-1, -2, -6, -11 from `Welcome`'s words; AC-4 typed → `.conversation`, the name fallback; AC-7 the Mac's sheet chain gone (source); AC-9 no mail-first words in the empty states (source).
- Screen tests: the first start ends at the first step (iPhone, iPad, Mac); typing a line makes a matter; the mail card's Not now; the name line.
