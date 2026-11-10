# F002 · The film anew from today's app — How

## Data

Nothing in the app is read or written. The film is files in `site/film/walkthrough/`:

| File | Today | After |
|---|---|---|
| `voiceover.txt` | the words of 14 October | the new words, approved in stage 4 |
| `voice.mp3` | the owner's ElevenLabs reading, 126.9 s | the new reading, through the ElevenLabs connector |
| `timing.json` | — (in `concept/film/`, not on the site) | each line's start and end in the film; read by the page, the sound and the captions |
| `walkthrough.vtt`, `.srt` | written by hand | written from `voiceover.txt` and `timing.json` |
| `img/*.webp` | six pictures of 14 October | the same six screens, taken from today's demo |
| `index.html` | every moment in absolute seconds | every moment as a line and an offset into it |
| `walkthrough.mp4`, `-720.mp4`, `poster.webp` | rendered on 10 November | rendered anew |

Schema change: none

## Sync and other devices

Not touched. The film shows sync (a tick on the iPad seen on the iPhone and the Mac), as the app does it today. Nothing in it is new behaviour.

## Privacy

- **To ElevenLabs:** the film's words only, on the owner's account, through the connector. They are the demo's story: Mum, Dr. Brandt, Helga, Healthbridge. These are made-up names; no one's real data.
- **The pictures:** taken from the demo's store (`--demo`), never from the owner's own matters.
- **What the film says about privacy** is checked against `site/privacy.html` and the app, line by line (AC-3): with Pro, what is sent is pseudonymised first, on the device (`ModelChoice.swift:10`); without Pro, Apple's model reads on the device and nothing leaves it.

## The AI

The app's AI is not touched. No prompt changes.

**The voice:**
- ElevenLabs, through the connector's `creative_generate_speech`.
- The voice is "Jenny", as on 14 October (`concept/film/voice-jenny-5.mp3`). The library has several Jennys; the film's is British ("Mum"). The likely one is "Jenny - Upbeat corporate" (`dHZt8yoqTSDwjElzgqey`).
- **First, one line as a test:** "This is Causabee.", read by that voice, put beside the same line of 14 October. The owner hears both and says "same". Only then is the whole reading made.
- **Cost:** `estimate_only` first. Then one reading of the whole text, in two takes (the connector's default), never a retry that charges again. The owner picks the take.
- **Checked:** the connector's `creative_transcribe_audio` writes down what the reading says, and that is compared word for word with `voiceover.txt` (AC-4). A word read wrong is read again for that line only.

## Calendar and Reminders

Not touched.

## When it fails

Nothing in `site/` is replaced until every step has worked; the film online stays as it is.

| What fails | What happens |
|---|---|
| The test line does not sound like 14 October | Nothing more is spent. The owner finds the voice in ElevenLabs's history and names it |
| The connector is not connected or has no credits | It says so; the owner tops up or reconnects. Nothing is half-made |
| The reading misreads a word | The transcript shows it; that line is read again on its own and cut in |
| `time-voice.py` finds fewer pauses than lines | It stops and says how many it found. The reading is read again with a pause marked |
| The film would last longer than 129.6 s | `walkthrough.sh` stops before anything is replaced (AC-6). Lines are shortened in stage 4's words, not sped up |
| A picture from today's app does not show what a scene needs | The scene is told around what the app shows. The app is not changed; what looks wrong goes to the backlog |
| An overlay is off its row | The still at its moment shows it (AC-2); it is placed again before rendering |

## Where in the code

**Times from the voice, in one place.**
- `scripts/film/time-voice.py`:
  - reads the number of lines and their words from `voiceover.txt`, no longer from fixed lists of 18;
  - writes `site/film/walkthrough/timing.json`: each line's start and end in the film, and the film's length.
- `index.html`:
  - reads `timing.json` and writes every moment as `line + offset`, e.g. `--d: L(9, 1.2)`, so a moment stays on its word when the reading changes;
  - its `seek()` works as before.
- `soundtrack.py`:
  - takes its length and its effects' times from `timing.json`;
  - the music is the same groove, laid to the new length.
- `walkthrough.sh`:
  - makes the sound from `voice.mp3` with `soundtrack.py`, no longer copied from the old film;
  - takes the length from `timing.json`; the frame count follows from it;
  - stops if the length is over 129.6 s.
- A new `scripts/film/captions.py` writes `walkthrough.vtt` and `.srt` from `voiceover.txt` and `timing.json`.

**Pictures of today's app**, into `site/film/walkthrough/img/` only. The website's own pictures are F003.
- **The Mac:** `care-2880`, `overview-2880`. Made by `scripts/site-shots.sh` with a new `--into <folder>` option, so it writes there and not into `site/assets/img`.
- **The iPhone:** `iphone-care`, `iphone-overview`, `iphone-assistant`. From the app's `--demo --shot` modes in the iPhone 18 Pro simulator, with the status bar at 09:41. The bee button lower right is in them, as the app draws it.
- **The iPad:** `ipad-matter`, from `PadTests`.

**The overlays** are placed again on the new pictures:
- by their pixel positions (`--x`, `--y`), measured on each picture;
- `render.swift --at` draws a still at every overlay's moment;
- `scripts/film/stills.sh` puts each still beside the same screen of today's app, for the owner's look (AC-2).

**The one bee (AC-5).**
- The film's own bee (`.fly`, `#pullbee`, `#boxbee`, the loupe's) starts from the bee button's place in each iPhone picture and goes back to it.
- On the iPad and the Mac it starts where the app's bee is in their pictures.

**Tests, in `Tests/MatterCoreTests/WebsiteLookTests.swift`, tagged `F002 AC-n`:**

| Criterion | Test |
|---|---|
| AC-1 | Vision reads every picture in `site/film/walkthrough/img/` and every film at each scene's middle: no "Claude", "Opus", "Auto mode", no "$" under an answer. F001 AC-3's exception for the film's own pictures ends. |
| AC-2 | The owner's look at the stills beside the app (`stills.sh`), recorded in the proof. A test checks every overlay's moment lies inside its scene. |
| AC-3 | `voiceover.txt`, the captions and every text in `index.html`: none of the phrases AC-3 lists, and "mail" only beside another source. |
| AC-4 | The captions are `voiceover.txt` word for word; each caption's times are its line's in `timing.json`; the transcript of the reading, kept beside it, matches the words. |
| AC-5 | The owner's look; the test checks each film bee's start point is the bee button's place in its picture. |
| AC-6 | Both films last `timing.json`'s length, no more than 129.6 s, with the page's SHA-256. F001 AC-2's fixed 129.6 moves to `timing.json`. The owner's play on causabee.app. |

**Shared:** the film's page, its sound and its captions are one source, `timing.json`, for every device that plays it.
**Not changed:** `Sources/`, `App/`, the teasers, `site/assets/img`, the rest of the website.
