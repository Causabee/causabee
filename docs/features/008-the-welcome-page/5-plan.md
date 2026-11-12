# F008 · The welcome page — Build

## Steps

1. **Tests first:** `WelcomeTests` (MatterCore) with every criterion it can hold, seen failing.
2. **The shared words:** `Welcome` in MatterCore — the four pages, the privacy line, the first step, the demo's line, the name line, the mail card.
3. **The typed door:** `TypedDoor` in MatterCore — typed words to an `Email` with id `typed:…`, read by `Spike` with `onDevice` as chosen; `MatterImport.apply` gives `typed:` the kind `.conversation`; the name falls back to the typed line.
4. **The iPhone and the iPad:** `WelcomeSheet` from `Welcome`, four pages, Start at the end; `FirstStep` in `OverviewScreen.empty`, with the iCloud line; what is added with no matters goes straight into a new matter.
5. **The Mac:** `IntroView` from `Welcome`; `FirstStep` where "No matters yet" stood; the setup no longer opens by itself.
6. **The name box and the mail card,** for both apps.
7. **The pictures:** three cut-outs from the demo, on the Mac and in the simulator.
8. **The pressure test:** ten made-up lines through Apple's model on this Mac; the names and dates checked.
9. **Everything:** `scripts/test.sh`, the screen tests on the iPhone, the iPad and the Mac, then `/ui-check 8`.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | `WelcomeTests` "F008 AC-1 · A few calm pages, then in" — four pages, three pictures, one line each, nothing asked; the iPhone's last page has no ticks (source) | unit |
| AC-2 | "F008 AC-2 · Private, said once" — the privacy line once in `Welcome`, nowhere else in the welcome's views | unit |
| AC-3 | "F008 AC-3 · The welcome ends at the first step" — both empty overviews draw `FirstStep` (source); screen test: a first start on the iPhone ends at "What's on your mind?" | unit, screen |
| AC-4 | "F008 AC-4 · Typed, it becomes the first matter" — `TypedDoor` gives an `Email` with `typed:`, `MatterImport` makes a `.conversation` source, the name falls back to the line; screen test: typing a line makes a matter | unit, screen |
| AC-5 | "F008 AC-5 · Added, it becomes the first matter" — with no matters, the card's question is skipped (source: `PhoneShots`, `Conversation`) | unit |
| AC-6 | "F008 AC-6 · The demo is the second way" — the demo's line is a link under the step, not a filled button (source) | unit |
| AC-7 | "F008 AC-7 · Nothing asked at the door" — the Mac's chain to `SetupAssistant` is gone (source) | unit |
| AC-8 | "F008 AC-8 · Mail is offered once there is a matter" — `MailOffer.shows(matters:accounts:later:)` | unit |
| AC-9 | "F008 AC-9 · Empty is the first step" — no mail-first words in either empty state (source) | unit |
| AC-10 | "F008 AC-10 · Already in use elsewhere" — `FirstStep.waitsForCloud(signedIn:imported:since:now:)` | unit |
| AC-11 | "F008 AC-11 · The same welcome on every device" — both welcomes take their pages from `Welcome` (source) | unit |
| AC-12 | "F008 AC-12 · Your name, asked once" — `NameLine.asks(names:)`, the Mac's fill-in from its user name (source) | unit |

## The UI check

`/ui-check 8` after the code; its report `ui-check.md` in this folder, "Verdict: pass" before the gate.

## What it adds to the manifesto

19. **Simple to start, more as you grow.** The first start asks for nothing before it is needed: mail, iCloud, Pro and your name come when they help, never at the door. Tested by `WelcomeTests` "F008 AC-7".

## The line for the release notes

- **A calmer first start:** four short pages, then your own Causabee — type what's on your mind or add a screenshot, photo or file, and it becomes your first matter.
