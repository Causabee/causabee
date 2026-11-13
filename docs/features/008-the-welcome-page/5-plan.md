# F008 · The welcome page — Build

## Steps

1. **Tests first:** `WelcomeTests` (MatterCore) with every criterion it can hold, seen failing.
2. **The shared words:** `Welcome` in MatterCore — the four pages, the privacy line, the first step, the demo's line, the name line, the mail card.
3. **The typed door:** `TypedDoor` in MatterCore — typed words to an `Email` with id `typed:…`, read by `Spike` with `onDevice` as chosen; `MatterImport.apply` gives `typed:` the kind `.conversation`; the name falls back to the typed line.
4. **The iPhone and the iPad:** `WelcomeSheet` from `Welcome`, four pages, Start at the end; `FirstStep` in `OverviewScreen.empty`, with the iCloud line; what is added with no matters goes straight into a new matter.
5. **The Mac:** `IntroView` from `Welcome`; `FirstStep` where "No matters yet" stood; the setup no longer opens by itself.
6. **The name box and the mail card,** for both apps.
7. **The pictures:** three cut-outs of the demo's matters per device, cropped from the introduction's own shots (`App/Resources/Intro/welcome-N.png`, `phone-welcome-N.jpg`) — a matter's Next card, the tasks and dates found, a question and its answer.
8. **The pressure test:** ten made-up lines through Apple's model on this Mac; the names and dates checked.
9. **Everything:** `scripts/test.sh`, the screen tests on the iPhone, the iPad and the Mac, then `/ui-check 8`.

10. **The start credit (after the owner's "Strat credit into F008", 13 November):** the beeserver's `POST /v1/start`, `giveStart`, `startCredit`, `/admin/start-forget` with `test/start.test.ts`; the first-step paragraph in both prompts (`extract-v18`, `device-2`) and the net in code (`Welcome.grounded`, `nameDates`); the apps ask once (`BeeServer.askStart`), the line, the bar's name, the used card (`StartCreditUsed`); the pressure test with both readers and three typo lines.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | `WelcomeTests` "F008 AC-1 · A few calm pages, then in" — four pages, three pictures, one line each, nothing asked; the iPhone's last page has no ticks (source) | unit |
| AC-2 | "F008 AC-2 · Private, said once" — the privacy line once in `Welcome`, nowhere else in the welcome's views | unit |
| AC-3 | "F008 AC-3 · The welcome ends at the first step" — both empty overviews draw `FirstStep` (source); screen test: a first start on the iPhone ends at "What's on your mind?" | unit, screen |
| AC-4 (13 Nov) | "F008 AC-4 · The first matter read by the best reader, told it is the first" — both prompts' versions, the paragraph only at the first step; "F008 AC-4 · Nothing made up" — `grounded`, names and dates; pressure test with both readers | unit, by hand |
| AC-4 | "F008 AC-4 · Typed, it becomes the first matter" — `TypedDoor` gives an `Email` with `typed:`, `MatterImport` makes a `.conversation` source, the name falls back to the line; screen test: typing a line makes a matter | unit, screen |
| AC-5 | "F008 AC-5 · Added, it becomes the first matter" — with no matters, the card's question is skipped (source: `PhoneShots`, `Conversation`) | unit |
| AC-6 | "F008 AC-6 · The demo is the second way" — the demo's line is a link under the step, not a filled button (source) | unit |
| AC-7 | "F008 AC-7 · Nothing asked at the door" — the Mac's chain to `SetupAssistant` is gone (source) | unit |
| AC-8 | "F008 AC-8 · Mail is offered once there is a matter" — `MailOffer.shows(matters:accounts:later:)` | unit |
| AC-9 | "F008 AC-9 · Empty is the first step" — no mail-first words in either empty state (source) | unit |
| AC-10 | "F008 AC-10 · Already in use elsewhere" — `FirstStep.waitsForCloud(signedIn:imported:since:now:)` | unit |
| AC-11 | "F008 AC-11 · The same welcome on every device" — both welcomes take their pages from `Welcome` (source) | unit |
| AC-12 | "F008 AC-12 · Your name, asked once" — `NameLine.asks(names:)`, the Mac's fill-in from its user name (source) | unit |
| AC-14 | `server/beeserver/test/start.test.ts` "F008 AC-14 · The start credit" — once per Apple account, the App Store's day, TestFlight's always and forgettable, no Xcode, not signed by Apple; "F008 AC-14 · The start credit, asked for at the first start on every device" (source) | server unit, unit |
| AC-15 | "F008 AC-15 · Said once, plainly, and named in Pro's use" — `showsStartLine`, `ProMeter` with `startCredit` | unit |
| AC-16 | "F008 AC-16 · It works as a top-up does, on every plan" — `Plan.proIsOn` with credit on the free plan and Plus | unit |
| AC-17 | "F008 AC-17 · Used: back to the device, and a top-up offered once" — `offersTopUp`, the card before the mail card on both overviews, Top up → `.topUp` | unit |
| AC-13 | "F008 AC-13 · Notifications asked later" — `Welcome.mayAskNotifications(starts:)`; every system question behind it, both apps count their starts (source) | unit |

## The UI check

`/ui-check 8` after the code; its report `ui-check.md` in this folder, "Verdict: pass" before the gate.

## What it adds to the manifesto

19. **Simple to start, more as you grow.** The first start asks for nothing before it is needed: mail, iCloud, Pro and your name come when they help, never at the door. Tested by `WelcomeTests` "F008 AC-7".

20. **A name is made of the words that came in.** What the bee calls a matter, and what it calls a date, is taken from what it read — its own language, its own words; a typo mended, nothing translated, nothing invented. Tested by `WelcomeTests` "F008 AC-4 · Nothing made up".

## The line for the release notes

- **A calmer first start:** four short pages, then your own Causabee — type what's on your mind or add a screenshot, photo or file, and it becomes your first matter.
