# F002 · The film anew from today's app — Why

## The problem

The film "One day with Causabee" is the first thing many people see on causabee.app. It shows the app of 14 October, and the app has changed since:

- **Old screens.** Costs under answers, "Auto mode", the bolt, "Claude Opus 5" in the chat, a matter page without its Digest of what came in.
- **The bee.** On the iPhone it stays low on the right through every scene, over the list and the bolt (the owner, 10 November: "the bee stays always lower right").
- **The words.** Some say what is no longer so, or put mail first: "With Auto on, Causabee has already fetched the new mail, and read it", "which mail it came from", "fetches your mail", "Your mail stays in your mail account". Causabee is not a mail app; mail is one source.

## Who has it

Everyone who opens causabee.app and plays the film. And the owner, who shows it when telling people about Causabee.

## What we know

- **The film.**
  - The page is `site/film/walkthrough/index.html`: 13 scenes, 129.6 s.
  - Its overlays — ticks, cards, highlights — sit on the pixels of six app pictures (`site/film/walkthrough/img/`, from 14 October).
  - It renders with `scripts/film/walkthrough.sh` (F001).
- **The voice.**
  - It is an ElevenLabs reading of `voiceover.txt`, made by the owner on 14 October.
  - `scripts/film/time-voice.py` cuts a reading into its lines and times each to its beat.
  - The picture follows the voice word by word, so new words need a new reading. That reading is the owner's to make: Claude has no ElevenLabs account.
- **Today's pictures.**
  - The Mac's come from `scripts/site-shots.sh`; the iPhone's from the app's own `--shot` modes in the simulator; the iPad's from `PadTests`.
  - In F001 the Mac matter page opened on its Digest, with what came in new on top, and its chat showed "OpenAI GPT-6.1 Sol".
- **F001's lesson.** A film checked against its own earlier render had its ticks off for everyone. Every scene of this film is checked against the app as it is today, by eye, before it goes online.

## The goal

The film shows Causabee as it is today, in words that are true: every source counts, one bee, the AI's name as the app says it.

## Not in this feature

- The website's other pictures and texts: F003.
- The teaser films (`site/film/teaser`).
- A longer film, or new scenes beyond the 13. A scene may be retold, not added.
- Changes to the app itself, to make it film better. Anything the film shows that looks wrong in the app goes to the backlog, not into this feature.
- Music and sounds: kept as they are, laid under the new voice.

## How we know it worked

The owner plays the film on causabee.app, on the Mac and on the iPhone, and sees today's app and hears true words, with no tick, card or highlight off its place.

## Principles it touches

- **1, every source counts the same:** the words name what comes in, not mail alone.
- **11, private, said as it is:** "Your mail stays in your mail account" becomes what is true, with Pro and without.
- **12, everywhere the same:** the Mac, the iPad and the iPhone show one matter, one state.
