# F001 · Polish, week 46: the website — Looks

## Screens and states

**The film.** Its three serif rules:

| Where in the film | Today | After |
|---|---|---|
| The titles — "One day with Causabee." and each scene's title (`.title`) | Source Serif 4, 600, 84 px, headline shape | Source Serif 4, **400**, 84 px, text shape |
| The words at the bottom — the captions in their white or dark pill (`.cap`) | Source Serif 4, 500, 44 px, headline shape | Source Serif 4, **400**, 44 px, text shape |
| The letter lying on the table (`.letter`) | **Georgia**, 400, 17 px | Source Serif 4, 400, 17 px, text shape |

- Size, line height, letter spacing, colour and place stay as they are.
- At 400 a title is a little lighter and wider than today. It is not moved to make up for it. If a title then needs two lines, it is shown to the owner first.
- The poster is the film's first frame: the title "One day with Causabee." over the cards.

**The screenshot of a matter.** The Lisbon trip on the Mac, taken anew in the same window size (1440 × 900 and 2880 × 1800). Under the answer: the AI's name as the app shows it today. Other small things may differ from 1 November; that is accepted (2-acceptance.md).

**The privacy page.** One line changes.

## Words

| Where | Text |
|---|---|
| Privacy page, under the title | Effective 10 November 2026 |

No other words change. The film's titles and captions keep every word.

## On each device

- **Mac** — wider than 900 px: the website plays the 1080p film.
- **iPhone and iPad** — narrower: the 720p film, the same picture scaled.
- The screenshot shows at 1440 or 2880 pixels by the screen's density, as today.

## Undo, and what the user can take back

Not needed for visitors. For the owner: every changed file is one commit, and the old film and pictures come back with `git revert`. The old versions stay in git.

## Accessibility

- The video keeps its label ("One day with Causabee: …") and its controls.
- The screenshot keeps its `alt` text. If the new picture shows something its `alt` no longer says, the `alt` is corrected to match.
- Regular weight on white is as readable as today: the same ink colour, at 44 and 84 px.

## Picture

Before anything is published, the owner gets two stills side by side, today and after, from the rendered film: the opening title, a caption, and the letter. Plus the new screenshot beside the old one.
