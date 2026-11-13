# F008 · The welcome page

- Stage: 5
- Lane: feature
- Started: 2026-11-12
- Branch: feature/008-the-welcome-page

## Gates

| Stage | Opened | The owner's word |
|---|---|---|
| 1 · Why | 2026-11-12 | Yes, go. |
| 2 · What | 2026-11-12 | Yes, go. |
| 3 · How | 2026-11-12 | Approved, go. |
| 4 · Looks | 2026-11-12 | Approved |
| 1 · Why | 2026-11-13 | Yes, go |
| 2 · What | 2026-11-13 | Yes, go, AC-14 but i want somehow test it of coure. |
| 3 · How | 2026-11-13 | approved |
| 4 · Looks | 2026-11-13 | Approved |

## Changes after a gate

<!-- A criterion or the spec changed after it was approved: the date, what changed, why. One line each. -->
- 2026-11-12, at How: AC-12's name is filled in on the Mac from its user name; on the iPhone and the iPad the field starts empty — iOS has no API for one's own contact card, and Contacts would be one more thing asked at the door.
- 2026-11-13, at Build: the start credit switches "Use Pro" on, unless the owner ever set it — in TestFlight 250 the credit was given, but Pro stayed off and nothing was read with it (the owner: "pro was not used or inactive"). A device that got it under 250 is switched on at its next start.
- 2026-11-13, at Build: the start credit is asked once per install, whatever token is kept — with a token kept, a device that had it once never asked again, and the owner could not try it twice (AC-14). The owner: "yes, do 251 with the once-per-install fix".
- 2026-11-13, at Build: back to Why — the start credit comes into F008, so a new person's first matter is read by the best model. The owner: "Strat credit into F008, and every user can top up for pro, light plus pro". What was built stays on the branch; What, How and Looks are opened again, and the first step read on the device (below) is decided anew in How.
- 2026-11-13, at Build: the iPhone's first step stands alone, as on the Mac — no "Overview" title and no search while there are no matters. The owner: "shouldnt this page be as simple as on mac w/o overview and search bar?"
- 2026-11-13, at Build: with no name from the reader, the first matter is named by its line before the date ("Muttis Reha started am 2.12.2026" is "Muttis Reha"), and a date given only as itself takes that name.
- 2026-11-13, at Build: the first step's typed words are read on the device with Pro too — with Pro, the cloud reader took "Muttis Reha startet am 23.11." for a note with no matter: no name, no date; Apple's model gives "Muttis Reha" and 23 November. The owner: "we agreed you derive a title and extract dates with on device" and "mac still not working".
- 2026-11-12, at Build: AC-13 added — the notification question waits for the second start, seen coming at the first matter in the simulator; the owner: "Approved".
