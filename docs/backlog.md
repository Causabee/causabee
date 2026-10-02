# Backlog

Small things noticed while using the app, to pick up later. Newest first.

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
