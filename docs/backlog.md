# Backlog

Small things noticed while using the app, to pick up later. Newest first.

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
