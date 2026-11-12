# F008 · The welcome page — What must be true

## Criteria

### AC-1 · A few calm pages, then in

- Given Causabee is opened for the first time
- When the welcome shows
- Then it is the promise and at most three pictures, each a light matter (a few lines, not a full page) with one short line under it; every page can be skipped, and no page asks for anything
- Holds for: iPhone, iPad, Mac · Pro and without Pro

### AC-2 · Private, said once

- Given the welcome
- When it is read through
- Then that names are disguised before anything is sent is said once, in one line — not on several pages, not as a paragraph
- Holds for: iPhone, iPad, Mac · all

### AC-3 · The welcome ends at the first step, in the person's own Causabee

- Given the last page of the welcome, and no matters yet
- When the person goes on
- Then they are in their own, empty Causabee, with one first step in front of them: a field to type what is on their mind, and a way to add a screenshot, a photo, a file or a scan — the first and largest thing on the page
- Holds for: iPhone, iPad, Mac · Pro and without Pro

### AC-4 · Typed, it becomes the first matter

- Given the first step
- When the person types a line or a few ("Mum fell, the care service visits on Thursday") and sends it
- Then the bee reads it like a note: it names the matter from what was typed and puts on it what it finds — a task, a date — as for anything that comes in; the matter opens and holds the typed words as their own; if the bee finds nothing, the typed line is the name (the owner, 12 November: "try to understand them and make a name out of it, and already a first thing")
- Holds for: notes and what is said in the chat (typed or spoken) · iPhone, iPad, Mac · Pro and without Pro (without Pro, Apple's model on the device reads it, nothing leaves it)

### AC-5 · Added, it becomes the first matter

- Given the first step
- When the person adds a screenshot, a photo, a file or a scan
- Then a matter is made from it and opened, as when it is shared to Causabee today
- Holds for: screenshots, photos, files and scans · iPhone, iPad, Mac · Pro and without Pro

### AC-6 · The demo is the second way, never the first

- Given the first step
- When the person looks for it
- Then "Look around in an example" (or the like) is there as a quiet line under the first step — never a filled button, never before it; and it is still reachable later from where the introduction is (⋯ on the iPhone and iPad, Help on the Mac)
- Holds for: iPhone, iPad, Mac · all

### AC-7 · Nothing asked at the door

- Given a first start
- When the welcome ends
- Then no setup follows by itself: not mail, not iCloud, not the plan, not Calendar, not "About you" — the Mac's setup assistant does not open on its own; everything in it can still be opened by hand (Causabee → Set Up Causabee … on the Mac, Settings on every device)
- Holds for: iPhone, iPad, Mac · all

### AC-8 · Mail is offered once there is a matter

- Given the first matter exists, and no mail account is set up
- When the person is on the overview
- Then one quiet card under the matters, "Also what comes by mail?", says what mail adds, with Set up — the setup that is there today — and Not now; after either it is gone for good, and mail is always in Settings; it never stands before the first step. Visible, never an obligation: no badge, no yellow, no count, nothing that waits for the owner
- Holds for: mail · iPhone, iPad, Mac · all (the owner, 12 November: "it needs to be visible, but not feeling like an obligation")

### AC-9 · Empty is the first step, everywhere

- Given there are no matters — on a first start, or after the last one was deleted
- When the overview shows
- Then it shows the first step of AC-3, with no words that put mail first ("Set Up Causabee … to bring in your mail", "Pull down to get new mail")
- Holds for: iPhone, iPad, Mac · all

### AC-10 · Already in use elsewhere: straight to the matters

- Given someone who uses Causabee on another device, opening it for the first time on this one, with iCloud bringing their matters
- When the welcome ends
- Then they land on their overview, and the first step is not put in front of matters that are on their way (the empty page says they are coming while iCloud brings them)
- Holds for: iPhone, iPad, Mac · all

### AC-11 · The same welcome on every device

- Given the iPhone, the iPad and the Mac
- When the welcome is compared
- Then the pages, their words and the first step are the same — laid out for each screen
- Holds for: iPhone, iPad, Mac · all

### AC-12 · Your name, asked once, after the first matter

- Given the first matter exists, and the bee does not yet know the person's name
- When the matter is open
- Then one line asks it — on the Mac with the Mac's own user name filled in ("This is you: Alex? · Change"), on the iPhone and the iPad as an empty field ("Your name"), iOS having no card of its own; once answered it is not asked again, on any device; until then the matter works as it does
- Holds for: iPhone, iPad, Mac · all (the owner, 12 November: "Yes, asked for the name. That's a good one.")

### AC-13 · Notifications asked later, not at the door

- Given Causabee is started for the first time
- When something with a date is made, or something new comes in
- Then nothing asks to send notifications on that first start; from the second start on, the system's question comes once — only when a matter has a date or something new came in — the same rule on every device
- Holds for: all sources · iPhone, iPad, Mac · all (the owner, 12 November: "place the ask for notification carefully … maybe on the second start or the third start"; approved: "Approved")

## Must not change

- Mail's setup, step by step, once it is opened: the IMAP and label tests (`IMAPTests`, `LabelIntakeTests`, `UnreadMailTests`).
- What is shared to Causabee is taken in as today: `DeviceIntakeTests`, `IntakeOfferTests`.
- The app never says the AI reads only mail; the introduction names every source: `SaidAsItIsTests`.
- The demo's matters and what they hold: `DemoData` as it is; the Mac's and the iPhone's screen tests that run on it (`CausabeeAppUITests`, `CausabeePhoneUITests`).
- A fourth open matter on the free plan still asks for the plans first (`Store.mayStartMatter`).
- Every source counts the same — the manifesto's tests (`ManifestoTests`).
- The SwiftData schema: untouched.

## Open questions

None. The owner, 12 November: typed words read by the bee like a note (AC-4), the name asked after the first matter (AC-12), mail offered as one quiet card (AC-8).
