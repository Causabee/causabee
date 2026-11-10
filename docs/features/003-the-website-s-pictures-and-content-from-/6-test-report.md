# F003 · The website's pictures and content from today's app — Proof

## Each criterion

| Criterion | Test | Result |
|---|---|---|
| AC-1 | `WebsiteLookTests` "F003 AC-1 · The website's pictures are today's app": every picture is used by the page (the teasers' own excepted), none is the file of before F003, Vision finds no cost, no "Auto mode", no AI but GPT-6.1 Sol | pass |
| AC-2 | `WebsiteLookTests` "F003 AC-2 · Every sentence on the website is true for the app": the page's whole text, hidden parts too; "Sequoia 15" always with what needs macOS 26 | pass |
| AC-3 | `WebsiteLookTests` "F003 AC-3 · Every picture of the app says in words what it shows" | pass |
| AC-4 | The look at each group, side by side on the page: the iPhone's three and the iPad's are one fresh demo, one state of Mum's matter — the suggestion not yet taken, no next step that disagrees; and the owner's look | pass |

All three tests failed before the build (10 November, step 1).

## Everything else still works

- **Unit tests:** 624 in 135 suites pass, on 10 November, after the last change; F001's and F002's website and film tests among them.
- **The app is untouched:** `git diff main -- App Sources` is empty; `App/Resources/Intro` was left alone (`intro-shots.sh --site-only`). So the screen tests were not run.
- **The page:** looked at in the browser at 1280 wide and at 375 (iPhone): every picture loads at its size, no sideways scroll on the phone. Photographed whole at both widths (`concept/f003-page/`).
- **Kept as they were:** the teasers' own pictures (`care-2880`, `iphone-care`); the film; the privacy page; `numbers.html` (only its stylesheet `?v=` follows the file).
- **One frame changed shape:** the iPad's, from 4:3 to the iPad Air's 2360 × 1640, so the bee in its corner is not cut off (`styles.css`).
- **Corrected on the way:** the Why first said visitors saw the old animations; they were hidden. The Looks first said the big matter picture is Mum's; it is the Lisbon trip, as before, with its own question.

## The AI's answers

No AI involved.

## The owner's own try

- **10 November:** the owner saw the sheet of the pictures before and today, and said "built, show me".
- The page photographed whole at Mac and iPhone width, for the owner's read beside the app.
