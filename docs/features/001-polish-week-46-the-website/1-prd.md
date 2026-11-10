# F001 · Polish, week 46: the website — Why

## The problem

Three things on causabee.app look or say what is no longer true.

1. **The film's serif.** The owner, on 10 November: "in the movie you use a different font than on the website, i want source serif 4". The film's titles are Source Serif 4 too, but they do not look like it: semibold, in the font's narrow headline shape. The website's serif is regular, in its text shape. The film looks like another brand.
2. **The screenshot of a matter.** The big picture of a matter on the Mac shows "Claude Opus 5" under an answer. The product has used one AI, GPT-6.1 Sol, since 9 November.
3. **The privacy page's date.** It says "Effective 28 October 2026". It changed on 10 November: an own key is OpenAI only, Sign in with Google is not offered, and where full texts go.

## Who has it

Everyone who opens causabee.app. The film and the screenshot stand in the middle of the main page. The privacy page is what a careful person reads before they trust the app.

## What we know

- **Film:**
  - The website's serif is weight 400 with `font-optical-sizing: none` (`site/styles.css:76–77`, `:380`).
  - The film's page, `site/film/walkthrough/index.html`, sets its titles to `font: 600 84px` (line 28) and the pill to `500 44px` (line 25), with no optical-size setting.
  - The teaser film (`site/film/index.html:5`) already sets the text shape.
  - The video was last rendered on 14 October.
- **Screenshot:**
  - It is `site/assets/img/matter-1440.webp` and `matter-2880.webp` (`site/index.html:312`), last changed on 1 November.
  - It shows "Claude Opus 5" bottom right in the chat, under the answer about the Lisbon trip.
  - Found by the second assessment, and seen by eye.
- **Privacy page:** `site/privacy.html:33`. The policy changed in commits `8d1d225` and `7005d23` on 10 November.

## The goal

What the website shows and says is the product as it is today, in its own type.

## Not in this feature

- The film's words, timing, voice, scenes and layout, its sans-serif text, and the teaser film.
- Any other screenshot. They are checked in this batch only for the AI's name; anything else found goes to the backlog.
- The text of the privacy policy. Only its date.
- The app itself.

## How we know it worked

On causabee.app:
- The owner sees the film's serif as the same as the page's headlines.
- No picture names an AI other than GPT-6.1 Sol.
- The privacy page's date is the day it last changed.

## Principles it touches

Principle 11, Private: what Causabee says about privacy is exactly what it does. The page's date is part of what it says.
