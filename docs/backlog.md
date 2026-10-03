# Backlog

Small things noticed while using the app, to pick up later. Newest first.

## Before the App Store

- **The assistant as a proper chat, second round** (AssistantView.swift, Conversation.swift,
  AssistantSheet.swift). The first round is in: the thread is followed at the bottom with
  "↓ New answer", the steps of asking are said as they go (AskSteps.swift), Stop / Try again /
  Copy, one question at a time, and on the iPhone Return starts a new line. The views stay our
  own: no open-source chat kit for SwiftUI runs on the Mac, and ours are lines with sources and
  cards. Still to do: Markdown in the answers (Foundation's `AttributedString(markdown:)` first;
  a renderer — Textual — only if that is not enough), streaming the answer, editing a question,
  a new conversation, search. On the iPhone an answer cannot be asked for again yet, and a
  question stopped there goes back into the field instead of staying in the thread. (2026-10-03)
- **Sharing a matter with the family.** The family that cares for Mum together: each with their
  own matter and mail, private, and one shared board beside it — tasks and who does them, dates,
  notes, files someone shares; claim a task ("I'll do it"), tick it off, see what changed. Mail,
  the assistant and the names behind the disguises are never shared. SwiftData syncs only the
  private database, so the board is its own CloudKit zone shared with `CKShare`. First step
  without any sync: "Send the status" as a message. (2026-10-02)

## Overview

- **More out of the overview when there are many matters.** Now the overview is one long column
  of cards (`activeMatters`: overdue first, then by the next date, then by name), with the quiet
  and the closed ones folded away underneath (`OtherMattersList`). With five matters that reads
  well; with fifteen, the card that matters today is a long scroll away, and every card takes the
  same room whether its next step is today or in six weeks. Ideas, to choose from:
  - **By when, not one list:** "Overdue", "This week", "Later" as section titles over the cards
    (sticky, as the matter page's titles in the UI item below). Later ones shrink to one line —
    the name and "Next, on Nov 12" — and open to their card on a tap.
  - **Whose turn:** a quiet switch over the cards — "For me", "Waiting", "All" — from what the
    tasks already know (mine, shared, someone else's). "Waiting" lists, across all matters, who
    still owes an answer and since when: the chasing list for the owners' association.
  - **The week across matters:** a strip under the title with the next seven days and their
    dates and deadlines from every matter, a dot per matter; a tap on a day lists them.
  - **Pinned on top:** the one or two matters that matter most right now stay first, whatever
    their dates (the pin exists in Figma's "Pinned item · lighter").
  - **A summary that says more:** "9 matters are going on. 7 have something overdue." could name
    the most urgent ones: "Overdue: the bath seat prescription (Care for Mum) and 6 more."

  Same on the Mac's overview. Drawn in Figma with the demo's matters doubled to fifteen: "Overview
  with many matters". **Chosen: the week across matters and pinned on top** (3 + 4) — the seven
  days as a strip under the search, a dot per date (orange where something is overdue), the
  selected day's things listed under it; the pinned matter as its card; every other matter one
  line, overdue ones in orange. (2026-10-02)

## Welcome

- **The iPhone's welcome page needs an overhaul, in content and look** (Welcome.swift; ⋯ →
  Introduction, and at the first start). Now: the bee, "Matterbee", one long paragraph of what it
  does, then "What it needs" as four ticked rows with long grey explanations (iCloud, Mail, an AI
  key, a list of names), then Try the demo / Start. It reads like a checklist of parts, not like a
  welcome. What it could become: one short promise in the website's voice (care first — "Mum's
  care, a claim, a move: each in its own place"), one picture of a matter as it looks; the setup as
  short steps only where something is still missing (a tick and two words where it is done, no
  explanations for what already works); privacy in one line ("names are disguised before anything
  is sent"); the demo as the first thing to try, not a side button. Draw it in Figma first.
  (2026-10-02)

## The app icon

- **A badge with the mails waiting to be reviewed.** The number on Causabee's icon — in the Dock on
  the Mac, on the Home Screen on the iPhone — is the "3 new mails · Review" the overview already
  shows: mail under the label, read but not yet sorted in (`look.pending` in MailCheck.swift and
  PhoneMailCheck.swift). It goes when the mails are sorted in or the label has nothing new, and
  shows nothing in the demo. Mac: `NSApp.dockTile.badgeLabel`. iPhone: `setBadgeCount` on
  `UNUserNotificationCenter`, which needs the owner to allow badges once. So the number is right
  while the app is closed, the mailbox is looked at now and then in the background
  (`BGAppRefreshTask` on the iPhone; a timer while the Mac app runs): reading the label is free,
  nothing is sent. (2026-10-02)

## Widgets

- **A matter on the Home Screen.** A widget the owner sets up by choosing one matter (the
  widget's own setting, an `AppIntent` with the open matters to pick from). It shows the matter's
  name, its next step — what to do and by when — and the short why under it, as the matter page's
  "Next" says it. A tap opens that matter. Small: the next step only; medium: with the why and
  what is overdue; large: with the matter's summary too. iPhone first, the Mac's desktop widgets
  with the same code. Nothing new to work out: the overview's card says it all already — "Next, on
  Oct 3: …" and "Overdue since …" from `NextStep` (MatterCore), and the summary in
  `Matter.summary`. The widget only has to reach it: it runs apart from the app, so the app copies
  those lines for each open matter into the App Group (as the share extension's inbox does) whenever
  a matter changes, and calls `WidgetCenter.reloadTimelines`. (2026-10-02)

## Calendar and Reminders

- **Find a connected event again when it moves.** An appointment was added to the "Matterbee"
  calendar, then moved in Calendar to the owner's private calendar: the chip said "no longer in
  Calendar", because an event moved to another calendar or account gets a new id. A "Connect"
  by hand found it again. When a connected event or reminder is gone, Matterbee could look for it
  by itself — same day and nearly the same title (`findEvent`; for reminders the strict match
  outside the own list) — and connect to it again without asking, saying so on the chip
  ("moved to Private"). Only if nothing is found: "no longer in Calendar" with Add again.
  (2026-10-02)
- **Choose where dates and tasks go, plainly.** The owner wants to decide between a separate
  "Matterbee" calendar and their own default one, since the Matterbee calendar did not seem to
  sync clearly. Settings → Calendar and Reminders already has "Add appointments to" and "Add tasks
  to" (default: "Matterbee", made when first needed), but it was not found. Ideas: ask once, at the
  first Add ("Into a calendar of its own, “Matterbee”, or into Private?"); name the target on the
  button ("Add to Private"); check why the made "Matterbee" calendar did not sync — which account
  it was made in (iCloud first, then where the default one is). (2026-10-02)

## UI

- **Sticky section titles on the matter page.** While scrolling, the title of the section in view
  (TASKS, APPOINTMENTS AND DEADLINES, FILES, HISTORY …) stays just under the matter's title bar
  until the next section's title pushes it away. A `LazyVStack(pinnedViews: .sectionHeaders)`
  with each section's `SectionHeader` as the pinned header, on the same glass as the bar.
  (2026-09-30)

- **Copy a link.** A link in a matter can be copied, to paste it wherever it is needed: "Copy
  link" in the row's ⋯ menu on the Mac and the iPhone, and on a long press on the iPhone; the
  button says "Copied" for a moment. A tap on the name still opens it. To decide: whether a plain
  tap should copy instead of open. (2026-10-03)

- **Read a link for the assistant.** In a link's ⋯ menu: "Read for the assistant". Causabee
  fetches what the link points to and keeps its text with the matter, so the assistant takes it
  into account in its answers — and can name it as a source. The row then shows a small sign
  that it is read (and when); the menu offers "Read again" and "Stop using it". To decide: what
  is kept (the whole text or a digest), how a link behind a login is read (a Google Doc), and
  that the text goes out pseudonymised like everything else. (2026-10-03)
