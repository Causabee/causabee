# F003 · The website's pictures and content from today's app — What must be true

## Criteria

### AC-1 · Every picture is today's app

- Given every picture causabee.app shows of the app: `site/assets/img/*` as `site/index.html` uses them
- When it is compared with today's app, opened on the demo on its device
- Then it is that screen, taken from today's build with Pro on: the Digest with what is new on top, the one bee in its corner, no cost, no "Auto mode", no AI named but GPT-6.1 Sol
- Holds for: every picture the page uses, at every size it serves (`-1440`, `-2880`), Mac, iPad and iPhone. Pictures the page does not use are not on the website.

### AC-2 · Every sentence is true for the app a visitor downloads

- Given every sentence on the page — visible, in an alt text, or hidden in its code
- When it is read beside the app
- Then the app does it, today, as said. In particular:
  - what the Mac needs is said together with what works on it: Apple's model reads what comes in only on macOS 26 and later; on macOS 15 without Pro, only threads and senders are sorted
  - no cost, no date long past, no screen the app no longer has
  - mail is never the first or only source where all sources count
- Holds for: `site/index.html`, every section, on the Mac and the iPhone; with Pro and without

### AC-3 · Every picture says in words what it shows

- Given a picture's alt text
- When it is read without the picture
- Then it says what today's picture shows, in the page's own voice, nothing that is not in it
- Holds for: every `<img>` of the app on the page

### AC-4 · One matter, one state, side by side

- Given two or more pictures of the same matter that a visitor sees together (the iPhone's three, the iPad beside them)
- When they are looked at together
- Then they do not disagree: the same next step, the same tasks done or open
- Holds for: every group of pictures on the page. Where today's demo itself differs between devices (parked in `docs/backlog.md`), the pictures are chosen so that the difference is not side by side.

## Must not change

Checked against what people have today: causabee.app as it is, and the app in TestFlight and Beta 128.

- **The page's design:** its sections, their order, its type, colours and layout. A section may be told in other words, not added.
- **The film** (F002) and **the privacy page** beyond what AC-2 needs.
- **The links:** Download, Release notes, Join the beta, GitHub, Privacy, Support.
- **The tests:** `SaidAsItIsTests` and `WebsiteLookTests` keep passing; `FilmAnewTests` too.
- **The app:** nothing. `git diff main -- App Sources` stays empty.

## Open questions

None.
