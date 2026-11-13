# F008 · The welcome page — How

## Data

- **The welcome's words:** one shared set in MatterCore, `Welcome` (new, `Sources/MatterCore/Model/Welcome.swift`): the promise, at most three pages (picture name, title, one line), the privacy line, the first step's words, the demo's line, the mail card's words, the name line. Both apps draw from it, so the words are the same everywhere (AC-11) and a test can hold them.
- **Typed words (AC-4):** made into a message as a screenshot's text is today (`ScreenshotDoor.look` builds an `Email` from it): id `typed:<hash>`, subject the first line, body the whole text, from the owner, dated now. `MatterImport.apply` gives an id beginning `typed:` the kind `.conversation` — the owner's own word, a kind that exists today. So every task and date found leads back to the typed words, shown as the owner's.
- **The first matter:** `Matter.make` / `MatterImport.apply` as today. Its name is the bee's `matterTitle`, or the typed line (cut at 60 characters) when the bee gives none.
- **Your name (AC-12):** `Profile.names`, as the Mac's "About you" and the iPhone's Settings write it today. The line shows while `names` is empty. Saving makes the `Profile` if there is none, as `SetupAssistant.saveNames` does.
- **The mail card's "Not now" (AC-8):** `UserDefaults` key `mail.offer.later` on this device. The card shows only while `Keychain.accounts()` is empty (iCloud Keychain: a mailbox added on one device counts on all).
- **First start:** `intro.seen` as today. The Mac no longer opens `SetupAssistant` by itself: the chains at `CausabeeApp.swift:848-850` and `:885-887` go; `setup.later` stays read by nothing new.

Schema change: none

## Sync and other devices

- The matter, its tasks and dates, and the typed words' source sync through iCloud as anything that comes in does.
- The name syncs in `Profile.names`: answered on one device, the line is gone on every device once iCloud brings it (AC-12). The Mac syncs only with iCloud on (`CloudSync.mode`, off by default); without it, the Mac asks on its own.
- The mail card's "Not now" is per device: no synced field fits, and the schema stays. Setting up mail anywhere ends the card everywhere, through iCloud Keychain.
- **Already in use elsewhere (AC-10):** on a first start, signed in to iCloud and with nothing here yet, the overview waits for iCloud's first import (`PhoneCloudStatus`, `CloudSync`: an import event, at most 30 seconds, as `CloudCatchUp` waits on the Mac). Meanwhile the empty page says "Looking in iCloud for your matters …" above the first step. Matters or a `Profile` arrive: the overview shows them. Nothing arrives: the line goes and the first step stands alone. Signed out of iCloud, or the Mac with iCloud off: the first step at once.
- **An older build** on another device sees an ordinary matter, and a source of kind `conversation`, which it knows. Its own welcome stays as it was. It still opens its own setup by itself, as before.

## Privacy

- **Without Pro:** typed words and added files are read by Apple's model on this device. Nothing leaves it.
- **The first step's typed words, with Pro too:** read by Apple's model on this device (`Welcome.readsOnDevice`): it names the first matter and finds its dates; nothing leaves the device at the door.
- **With Pro** ("Use Pro" on, something left to use), everything else — what is added at the first step, and all that comes in after: read through the beeserver, names, addresses and numbers disguised first (`Pseudonymizer`). The privacy line on the first page says so once.
- The name stays in iCloud as today, never sent except as part of what is disguised.
- No Contacts access: not asked, not used.

## The AI

No prompt changes. Typed words go through the readers that exist:

- without Pro, `DeviceReader.read` (Apple's model) through `Extractor.readOnDevice`: a matter name (`isNew`, "No matters yet."), up to two to-dos, dates only from `DateFinder`;
- with Pro, the reader on the beeserver, as for a screenshot's text;
- without Apple Intelligence, `placeByRules`: no name, no tasks — the typed line is the name.

**Pressure test, in Build, on this Mac and in the simulator, with made-up lines only:** ten typed lines — short ("Umzug im März"), long, German and English, with a date ("the care service visits on Thursday"), with no task at all ("just thinking about the garden"). Each must give a matter, a sensible name or the line itself, no invented date. Without Pro on the device's model; with Pro, the demo account against the beeserver. A name that reads wrong is a prompt change: back to this stage with a new version.

## Calendar and Reminders

Not touched. Dates and tasks found go on the matter; to Calendar and Reminders only with a tap, as today.

## When it fails

- **Apple's model not on this device, or busy:** the rules read it; the matter is made with the typed line as its name and the words kept. No error shown: it worked, less fully.
- **Reading fails** (an error, the beeserver not reached): the matter is still made with the typed line, the words kept, and one line on the matter: "Not read yet — your words are kept." It is read again on the next check, as a held mail is.
- **Pro is waiting** (`ProWait`, nothing left to use): Apple's model reads it, as without Pro.
- **A file Causabee cannot read:** as today — the card says so, nothing is made.
- **Nothing typed and Send tapped:** the button is off while the field is empty.
- **iCloud's first import never answers:** after 30 seconds the first step stands alone; matters that come later show as they come.
- **The name left empty:** the line stays on the first matter until answered; nothing else waits on it.

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

**Pictures:** the Mac's from `scripts/intro-shots.sh` on the demo, at most three, chosen at Looks; the iPhone's in the simulator, as `ec2461f` made them. Lighter shots may need a demo `--shot` of their own (`IntroShot`).

**Tests:**
- `WelcomeTests` (new, MatterCore): AC-1, -2, -6, -11 from `Welcome`'s words; AC-4 typed → `.conversation`, the name fallback; AC-7 the Mac's sheet chain gone (source); AC-9 no mail-first words in the empty states (source).
- Screen tests: the first start ends at the first step (iPhone, iPad, Mac); typing a line makes a matter; the mail card's Not now; the name line.
