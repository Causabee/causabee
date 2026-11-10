# F002 · The film anew from today's app — Build

## Steps

On the branch `feature/002-the-film-anew-from-today-s-app`.

1. **The voice, tested on one line.** "This is Causabee." through the ElevenLabs connector, in "Jenny - Upbeat corporate", put beside the same line of 14 October. The owner says "same", or names the voice from the ElevenLabs history. Nothing more is spent before that.
2. **The tests, failing.** `WebsiteLookTests`, tagged `F002 AC-1` … `AC-6`, as in the table below. F001 AC-2's fixed 129.6 s moves to `timing.json`. F001 AC-3's exception for the film's own pictures ends.
3. **The words.** `voiceover.txt` as approved in stage 4. AC-3's test passes on it.
4. **The reading.** The cost estimated first, then the whole text in two takes. The connector writes down what each says; the closer take is kept, as `voice.mp3`. A misread line is read again on its own.
5. **One timing.** `time-voice.py` reads its lines from `voiceover.txt` and writes `timing.json`. `captions.py` writes the captions from it. AC-4's test passes.
6. **Today's pictures**, into `site/film/walkthrough/img/` only:
   - the Mac's from `site-shots.sh --into`;
   - the iPhone's from `--demo --shot` in the simulator;
   - the iPad's from `PadTests`.
   AC-1's test passes on them.
7. **The page, scene by scene.** Every moment written as line plus offset. The overlays placed again on the new pictures. Scenes B, P and A retold as in stage 4. The film's bee starts from the app's bee.
8. **The stills.** `stills.sh` draws each moment beside today's app. The owner looks at them before rendering (AC-2, AC-5).
9. **The sound and the film.** `soundtrack.py` takes its length and its times from `timing.json`. `walkthrough.sh` makes the sound from the new voice, renders, and stops if the film is over 129.6 s. AC-6's test passes.
10. **Everything else:** `scripts/test.sh`. `git diff main -- App Sources` stays empty, so the screen tests are not needed: the app is not touched.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | `WebsiteLookTests` "F002 AC-1 · The film's pictures show today's app": Vision reads every picture in the film's `img/` and a frame of each scene. No Claude, Opus, Auto mode, nor a cost | unit |
| AC-2 | `WebsiteLookTests` "F002 AC-2 · Every overlay's moment is inside its scene"; the owner's look at the stills beside today's app | unit, owner |
| AC-3 | `WebsiteLookTests` "F002 AC-3 · The film's words are true and name every source": voice, captions, the page's text | unit |
| AC-4 | `WebsiteLookTests` "F002 AC-4 · Captions, timing and reading are the same words" | unit |
| AC-5 | `WebsiteLookTests` "F002 AC-5 · The film's bee leaves from the app's bee"; the owner's look | unit, owner |
| AC-6 | `WebsiteLookTests` "F002 AC-6 · Both films last as long as their timing, at most 129.6 s, drawn from today's page"; the owner's play on causabee.app | unit, owner |

## What it adds to the manifesto

Principle 11, said as it is: a film or a picture of the app shows the app as it is today. When the app changes what it shows, the film is renewed, or the change waits. Its test: `WebsiteLookTests` F002 AC-1.

## The line for the release notes

The film on causabee.app shows Causabee as it is today.
