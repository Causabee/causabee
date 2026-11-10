# F002 · The film anew from today's app — Proof

## Each criterion

| Criterion | Test | Result |
|---|---|---|
| AC-1 | `FilmAnewTests` "F002 AC-1 · The film's pictures show today's app": none of October's pictures is left; Vision reads every picture in the film's `img/` — no Claude, Opus, Haiku, Mistral, Anthropic, "Auto mode", nor a cost | pass |
| AC-2 | `FilmAnewTests` "F002 AC-2 · Every moment of the picture is a word of the voice, inside its scene"; and the owner's look at every render | pass |
| AC-3 | `FilmAnewTests` "F002 AC-3 · The film's words are true and name every source": the voice, both captions and the page's text | pass |
| AC-4 | `FilmAnewTests` "F002 AC-4 · Captions, timing and reading are the same words" | pass |
| AC-5 | `FilmAnewTests` "F002 AC-5 · The film's bee leaves from the app's own bee" — the pixel under the bee's start is the app's yellow button; and the owner's look | pass |
| AC-6 | `FilmAnewTests` "F002 AC-6 · Both films last as long as their timing, at most 129.6 s, drawn from today's page" — 118.3 s | pass |

All six failed before the build (10 November, step 2, and at the start of step 7 for AC-2 and AC-5).

## Everything else still works

- **Unit tests:** 621 in 135 suites pass, on 10 November, after the last change. F001's four `WebsiteLookTests` pass; F001 AC-2 now takes the film's length from `timing.json`, as the criteria said it would.
- **The app is untouched:** `git diff main -- App Sources` is empty, so the screen tests on iPhone, iPad and Mac were not run.
- **The website:** only the film's files and its `?v=` (film 6, poster 4) changed. The other pictures and texts are F003.
- **Captions:** `walkthrough.vtt` and `.srt` are written from the timing. The website still plays the film without a captions track, as before: with a `<track>`, Safari on a real iPhone did not start the film (`site/index.html`). Unchanged.

## The voice

- Carolyn – Warm Grounded Narrator (`4rgssJ1pg3E9c0U78Iid`), `eleven_v4`, the whole text in one reading with the control tags of October; never cut, stitched, sped up or shifted. The picture is timed to it.
- The owner chose the voice and the model by ear. On the way: Jenny – Upbeat corporate (not October's voice), then the new lines stitched between October's and matched in pace and pitch (they sounded like a machine), then `eleven_v3` (not like Carolyn). The owner: "it is about a personal touch, not software code".
- Read three times on v4, each time because the words had to be truer: "gather the papers for the visit" (the demo's real new item), then not calling it a task.
- ElevenLabs, all readings and tests of F002: about 47,000 credits.
- The transcript in `voice-transcript.txt` is ElevenLabs' word list of the chosen take. It also lists the tags, so it may align the text more than it listens; the owner heard the take.

## The AI's answers

No AI in the app is involved. The voice is ElevenLabs, made through its connector on the owner's account.

## The owner's own try

The owner watched each render on 10 November and said what was wrong; each was fixed and rendered again:

- **First render:** "it's not a task. It's a suggestion" — line 10 and 12 rewritten and read anew; the suggestion is taken with the thumb and flies to the Plan. "I saw … the bubble before the [chat] appeared" — the morning's Mac taken with the chat closed. "Looks a bit boring" — scenes with depth, the Mac growing from where it stood, the finger travelling to what it taps, springing rings.
- **Second:** the marks not precise and cut off at 0:44; the bee not flying onto its button at 1:24; the speech bubble already there at 1:30; the chat's reveal "like 1998 PowerPoint" at 1:35; the iPhone beside the Mac at 0:13 and 1:51 — each fixed: the bee flies out of and back onto its button, the bubble pops in, the answer comes line by line from the chat's own picture, the iPhone stands over the Mac's corner.
- **Third and fourth:** a mark still cut off at 0:43, and "don't mark the text … looks cheap" — every highlight taken out; the voice says it.
- **Then:** "done".

Found on the way, parked: the demo's care matter shows a different next step on each device (`docs/backlog.md`).
