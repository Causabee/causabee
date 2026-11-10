# F002 · The film anew from today's app — What must be true

## Criteria

### AC-1 · Every picture is today's app

- Given the film's pictures of the Mac, the iPad and the iPhone (`site/film/walkthrough/img/`)
- When they are compared with today's app, opened on the demo on each device
- Then each is a picture of that screen, taken from today's build: no cost under an answer or a reading, no "Auto mode" chip or bolt the app no longer shows, and no AI named but GPT-6.1 Sol
- Holds for: every scene, Mac, iPad and iPhone, with Pro, as the demo shows it

### AC-2 · Every tick, card and highlight is on its place

- Given the film's overlays: ticks, strikes, rings, taps, cards and highlights
- When the film stands still at the moment each one appears
- Then it sits on the row, button or field it names in today's picture, as the owner sees it beside the app itself
- Holds for: every overlay in the 13 scenes, at 1080p and 720p

### AC-3 · The words are true and name every source

- Given what the film says and shows in words: the voice, the captions (`walkthrough.vtt`, `.srt`) and every text on screen
- When each line is read against today's app and the bee's manifesto
- Then it says only what the app does today; where it holds for everything that comes in, it names the sources or none, never mail alone; and what stays private is said as it is, with Pro and without
- Holds for: every line. None of these is left: "fetched the new mail", "which mail it came from", "fetches your mail", "Your mail stays in your mail account", "2 mails read", "Read for $"

### AC-4 · Voice, captions and picture go together

- Given the new reading, the captions and the film
- When it plays
- Then the captions are the reading, word for word; each scene's moment (a tick, a tap, a name that changes) comes on the word that names it; the music lies under the voice as before
- Holds for: both films, the version the website plays and its captions

### AC-5 · One bee

- Given a scene on the iPhone, the iPad or the Mac
- When the bee is seen
- Then there is one bee in it: the one the app shows, where the app shows it, and the film's own bee flies from there and back
- Holds for: every scene with a device in it

### AC-6 · causabee.app plays the new film

- Given causabee.app
- When the owner plays the film in Safari on the Mac and on the iPhone
- Then the new film plays, with its poster and captions, at no more than today's length, 129.6 s
- Holds for: the 1080p and 720p films, the poster, the captions; the Mac and the iPhone

## Must not change

Checked against what people have today: the film on causabee.app, and the app in TestFlight and Beta 128.

- **The story:** one day with Mum's care, on the Mac, the iPad and the iPhone, in its 13 scenes and their order. A scene may be told in other words.
- **The look:** Source Serif 4 at 400 in its text shape — `WebsiteLookTests` F001 AC-1. The bee's drawing, the colours, the opening and the closing card.
- **The music:** the same, laid under the new voice.
- **The film is drawn from its page:** both films carry the page's SHA-256 — `WebsiteLookTests` F001 AC-2. Its fixed 129.6 s moves to the new length, in the same change.
- **The rest of the website:** its pictures and texts are F003; `SaidAsItIsTests` and `WebsiteLookTests` F001 AC-3 and AC-4 keep passing.
- **The app:** nothing. `git diff main -- App Sources` stays empty. What looks wrong in the app, seen while filming, goes to the backlog.

## Open questions

None.

**Decided by the owner, 10 November ("yea both"):**

1. **The new reading** is made on the owner's ElevenLabs account, with the voice of 14 October. Claude makes it through the ElevenLabs connector, if it can; otherwise the owner does. The words come to the owner first, in stage 4, before anything is read.
2. **The bee on the iPhone** stays where the app puts its button, lower right, and is the film's one bee: it flies from the button when it works, and back (AC-5). Moving the button in the app is not this feature.
