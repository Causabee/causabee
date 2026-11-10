# F001 · Polish, week 46: the website — How

## Data

Only website files change. No model, no store, no setting.

- `site/film/walkthrough/index.html`: its serif lines get weight 400 and the text shape. That covers `.title` (line 28), `.cap` (line 25) and any other rule that uses `var(--serif)`.
- `site/film/walkthrough/walkthrough.mp4` (1080p) and `walkthrough-720.mp4`: rendered again from that page, with the same sound.
- `site/film/walkthrough/poster.webp`: the film's first frame, again.
- `site/assets/img/matter-1440.webp` and `matter-2880.webp`: taken anew from the demo.
- Any other picture the check finds naming another AI is taken anew too (AC-3). Today's guess: none.
- `site/privacy.html:33`: "Effective 10 November 2026".
- `site/index.html`: the `?v=` numbers of the changed films and pictures go up, so browsers fetch them anew.

`walkthrough-720-cc.mp4` is not served by the website: it was the captions test of 14 October. It stays as it is. Removing it is parked.

Schema change: none

## Sync and other devices

Not needed: nothing is synced. The website is published by GitHub Pages when main changes. Browsers fetch the new files because of the new `?v=` numbers.

## Privacy

Nothing leaves the device but the published website. The screenshot is of the demo's invented matters, never the owner's.

## The AI

No AI involved. The demo's answer in the screenshot is stored in the demo. Its label is drawn from today's code: an answer with no model of its own says GPT-6.1 Sol (`Assistant.swift:285`).

## Calendar and Reminders

Not touched.

## When it fails

| Step | If it fails | Then |
|---|---|---|
| Rendering the film | A frame is missing or the page did not load its font | Stop. Nothing is replaced. The old film stays online. |
| The film's length | It differs from today's by more than a tenth of a second | Stop: the sound would drift. |
| The screenshot | The demo window is covered, or Screen Recording is not allowed | Stop. The old picture stays. |
| Publishing | The website's workflow fails | The old site stays online. Fixed before the batch is called done. |

Nothing is replaced until its new version has been looked at.

## Where in the code

- **The film's page.** The serif rules in `site/film/walkthrough/index.html`, as `site/styles.css:380` does for the website.
- **Rendering.**
  - This Mac has neither Google Chrome nor ffmpeg, which `site/film/teaser/render.py` needs.
  - The frames are drawn with Safari's engine instead: `scripts/film/render.swift` gets three options — the size (1920 × 1080), the page's time in milliseconds (the walkthrough's `seek` takes ms), and read access to all of `site/`. Safari is also what most visitors watch it in.
  - 3,900 frames: 130 seconds at 30 a second.
- **Encoding.**
  - ffmpeg joins the frames into H.264, as for the first film.
  - It takes the sound unchanged from today's `walkthrough.mp4`.
  - It makes the 720p version by scaling the 1080p one, and the poster from the first frame.
  - **Needs ffmpeg, installed with Homebrew: `brew install ffmpeg`.** Approving this spec approves that install.
- **The screenshot.**
  - `scripts/site-shots.sh` takes all the website's Mac pictures from the demo.
  - Only `matter-1440` and `matter-2880` are copied into `site/`, plus any picture AC-3's check finds.
  - The script needs this Mac's screen for a minute, and Screen Recording for the terminal, as on 1 November.
- **The checks.**
  - A unit test reads the film's page and the website's styles: every serif rule is 400, in the text shape (AC-1).
  - A unit test reads the words in every picture with Apple's Vision, on the device, and fails on another AI's name (AC-3).
  - A unit test compares the privacy page's date with the day its text last changed in git (AC-4).
  - The rendered film is checked for its length and its sound track. The owner judges how it looks (AC-2).
