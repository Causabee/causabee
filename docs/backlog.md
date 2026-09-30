# Backlog

Small things noticed while using the app, to pick up later. Newest first.

## UI

- **Sticky section titles on the matter page.** While scrolling, the title of the section in view
  (TASKS, APPOINTMENTS AND DEADLINES, FILES, HISTORY …) stays just under the matter's title bar
  until the next section's title pushes it away. A `LazyVStack(pinnedViews: .sectionHeaders)`
  with each section's `SectionHeader` as the pinned header, on the same glass as the bar.
  (2026-09-30)
