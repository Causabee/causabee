# F001 · Polish, week 46: the website — What must be true

## Criteria

### AC-1 · The film's page draws its serif as the website does

- Given the film's page, `site/film/walkthrough/index.html`
- When any serif line in it is drawn: a title, the pill, a name
- Then it is Source Serif 4, weight 400, in its text shape (`font-optical-sizing: none`), as in `site/styles.css`
- Holds for: every serif line of the film; no sans-serif line changes

### AC-2 · The published film is drawn from that page

- Given causabee.app's film: the 1080p and 720p videos, the version with captions, and its poster
- When the owner looks at a title, such as "One day with Causabee.", beside a serif headline of the page
- Then the serif is the same: regular weight, the same shape
- Holds for: every version the website serves, in Safari on Mac, iPhone and iPad

### AC-3 · No picture names an AI other than GPT-6.1 Sol

- Given every picture causabee.app shows: `site/assets/img/*` and the film's poster
- When its words are read
- Then none names Claude, Opus, Haiku, Mistral or Anthropic, and any AI named is GPT-6.1 Sol
- Holds for: every picture, at every size the page serves (`-1440` and `-2880`)

### AC-4 · The privacy page's date is the day it last changed

- Given `site/privacy.html`
- When its text changed last, other than its date
- Then "Effective …" names that day: 10 November 2026
- Holds for: the privacy page; from now on, every change to it moves its date

## Must not change

- **The film:** its words, voice, captions (`walkthrough.vtt`, `.srt`), its scenes, and its length, within a tenth of a second.
- **The website's text:** nothing but the privacy page's date. `SaidAsItIsTests` keeps passing.
- **The other pictures:** a picture that names no AI is not touched.
- **The app:** nothing.

## Open questions

1. **The screenshot of a matter: taken anew, or only its words changed?**
   - *Taken anew* from today's demo on the Mac: the whole picture is the app as it is now. Other small things in it may change too, such as spacing and the words under the answer.
   - *Only the words changed*: "Claude Opus 5" is replaced by what the app shows there today. Everything else stays as on 1 November.
   - Recommended: taken anew. A picture that shows the product should be the product.
