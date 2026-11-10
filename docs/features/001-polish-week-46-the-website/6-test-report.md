# F001 · Polish, week 46: the website — Proof

## Each criterion

| Criterion | Test | Result |
|---|---|---|
| AC-1 | `WebsiteLookTests` "F001 AC-1 · Every serif line of the film is Source Serif 4, 400, in its text shape" — the rules and the elements' own styles | pass |
| AC-2 | `WebsiteLookTests` "F001 AC-2 · Both films are drawn from today's page" — 129.6 s, one sound track, the page's SHA-256 in each film | pass |
| AC-3 | `WebsiteLookTests` "F001 AC-3 · No picture names an AI other than GPT-6.1 Sol" — Apple's Vision reads every picture in `site/assets/img` and the poster | pass |
| AC-4 | `WebsiteLookTests` "F001 AC-4 · The privacy page's date is the day its text last changed" | pass |

All four failed before the change (10 November, first run: 21 issues). AC-2's look by the owner is below.

## Everything else still works

- **Unit tests:** 615 in 134 suites pass, on 10 November, after the last change.
- **The app is untouched:** `git diff main -- App Sources` is empty. So the screen tests on iPhone, iPad and Mac were not run. The app's own introduction pictures were restored after `site-shots.sh` wrote them.
- **The film:**
  - Both films last 129.6 s and carry the original sound, unchanged: the stream is copied, not encoded again.
  - **Corrected on 10 November, after the owner's look on causabee.app:** "the ticked off lines are off". The first published film was drawn over the pictures of 1 November. The film online before had been rendered on 14 October, over that day's pictures, which its ticks and cards are placed on. My earlier check compared against my own first render, not against the film that was online. That was wrong.
  - Now the film's own pictures are those of 14 October (commit `62e8b21`, when the film was last rendered; its page is unchanged since).
  - Compared with the film online before F001, every 2 s (65 frames): mean difference 1.3 of 255. The largest are where the serif changed (5 s, 125–129 s). At 33–39 s, plain text is drawn a hair differently by Safari's engine than by the Chrome of 14 October; nothing moves. The ticks at 66 s and 111 s are on their rows, as before.
  - 1080p is 12.5 MB (was 14.7); 720p is 6.2 MB (was 5.0).
- **Pictures not in this batch:**
  - overview, tasks, calendar, files, sources, `matter-phone`, the iPad's: unchanged.
  - The teaser films: unchanged.
- **Known and parked:**
  - The film shows the app of October: costs under answers, "Auto mode", "Claude Opus 5" in its chat, and the bee low on the right in every iPhone scene. All of it is for F002, the film anew.
  - The teaser pages still point to the website's pictures.
  - Both in the backlog.

## The AI's answers

No AI involved.

## The owner's own try

- **10 November, before publishing:** the owner saw the comparisons — title, closing lines, letter, the matter on the Mac, the iPhone's chat — and opened gate 5 with "built, show me".
- **On causabee.app, 10 November:** "the ticked off lines are off" and "the bee stays always lower right". The ticks are corrected, above. The bee is how the app looked in October, also in the film before F001: it goes to F002.
- **After the correction:** to be written with the owner's words.
