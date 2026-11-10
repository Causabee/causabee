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
  - Every tick and card was checked at 9 s and 110 s against the film as it was: in place.
  - 1080p is 12.5 MB (was 14.7); 720p is 6.2 MB (was 5.0).
- **Pictures not in this batch:**
  - overview, tasks, calendar, files, sources, `matter-phone`, the iPad's: unchanged.
  - The teaser films: unchanged.
- **Known and parked:**
  - The film's own pictures still show "Claude Opus 5" in its chat: in 18 of 130 seconds sampled.
  - The teaser pages still point to the website's pictures.
  - Both in the backlog.

## The AI's answers

No AI involved.

## The owner's own try

- **10 November, before publishing:** the owner saw the comparisons — title, closing lines, letter, the matter on the Mac, the iPhone's chat — and opened gate 5 with "built, show me".
- **On causabee.app, after publishing:** to be written with the owner's words.
