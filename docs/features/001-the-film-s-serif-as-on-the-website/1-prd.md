# F001 · The film's serif as on the website — Why

## The problem

The owner, on 10 November: "in the movie you use a different font than on the website, i want source serif 4". The film's titles are Source Serif 4 too, but they do not look like it. They are semibold, and the browser draws them in the font's narrow headline shape. The website's serif is regular, in its text shape. The film looks like another brand.

## Who has it

Everyone who opens causabee.app: the film "One day with Causabee" stands in the middle of the page, between the website's own serif headlines.

## What we know

- The website: every serif line is weight 400 with `font-optical-sizing: none` (`site/styles.css:76–77`, `:380`).
- The film's page, `site/film/walkthrough/index.html`: its titles are `font: 600 84px` (line 28) and the pill `500 44px` (line 25), with no optical-size setting. So big type takes the headline shape.
- The teaser film (`site/film/index.html:5`) already sets the text shape. Only the walkthrough lacks it.
- The video was last rendered on 14 October.

## The goal

Every serif line in the film looks like the serif on the website.

## Not in this feature

- The film's words, timing, voice, scenes and layout.
- The sans-serif text in the film.
- The teaser film.
- Other look issues on the website, such as the screenshot that still says "Claude Opus 5". They are parked for the next batch.

## How we know it worked

The owner looks at the film on causabee.app beside a headline of the page, and says the serif is the same.

## Principles it touches

None of the manifesto's principles: this is the website's look, not what the bee does.
