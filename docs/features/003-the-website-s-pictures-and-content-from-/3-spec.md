# F003 · The website's pictures and content from today's app — How

## Data

Nothing in the app is read or written. The website's files:

| File | Change |
|---|---|
| `site/assets/img/*.webp` | The Mac's from today's demo at 2880 × 1800 (`overview`, `matter`, `matter-phone`, `tasks`, `calendar`, `files`, `sources`, `assistant`); the iPhone's three and the iPad's from today's demo in the simulators. `care-1440`, `care-2880` and `iphone-care`, which the page does not use, go. |
| `site/index.html` | Words that are not true today, the alt texts, the pictures' `?v=`; the hidden animation stages go (see "Where in the code"). |
| `site/privacy.html` | Only if a sentence there says what AC-2 forbids. |

Schema change: none

## Sync and other devices

Not touched. The page shows sync as the app does it.

## Privacy

- The pictures come from the demo's own store (`--demo`), never from the owner's matters.
- Nothing is sent anywhere. No AI is asked.

## The AI

No AI involved. The page's words about the AI are checked against the app: GPT-6.1 Sol with Pro; Apple's model on the device only on macOS 26 and iOS 26 (`DeviceReader.isAvailable`); on macOS 15 without Pro, only threads and senders (`ModelChoice.swift:72`).

## Calendar and Reminders

Not touched.

## When it fails

Nothing on causabee.app changes until the branch is merged.

| What fails | What happens |
|---|---|
| The screen is not Retina, the Mac's pictures come out 1440 × 900 | `intro-shots.sh` says so and stops, nothing is written; the owner is told |
| The demo shows a state that disagrees between devices (parked) | The pictures shown together are chosen so the difference is not side by side (AC-4); it stays in the backlog |
| A crop in `site-assets.py` no longer fits today's layout | The crop is measured again on the new shot, with `find.swift`, before it is used |
| A sentence cannot be made true without a change to the app | The sentence goes or says less; the app is not changed; the gap goes to the backlog |

## Where in the code

**The pictures.**
- `scripts/intro-shots.sh` gets a `--site-only` option: it takes the shots into `scripts/shots` and leaves `App/Resources/Intro` alone, so the app stays untouched. With Pro on and the chat as each picture needs it (`--no-assistant` where the page shows no chat).
- `scripts/site-assets.py --pictures` cuts the Mac's pictures; each crop measured again on today's shots.
- The iPhone's (`iphone-overview`, `iphone-matter`, `iphone-assistant`) and the iPad's (`ipad-matter`) from the simulators, as F002 took them: `--demo`, `--open`, `--part`, Pro on, a fresh install, the status bar at 09:41. The iPhone's at 804 × 1748 and the iPad's at 2000 × 1500, as the page's frames are now.

**The words** in `site/index.html`:
- The macOS line, beside "Requires macOS Sequoia 15 or later", in both places: what works on 15 and what on 26.
- "One AI, only with Pro": without Pro, Apple's model on macOS 26; on macOS 15, threads and senders.
- The matter page's text: what the page shows today — the Digest with what is new on top, the next step, the plan by day — not "a journal of cards".
- Each section read beside today's app; only what is no longer true changes.

**The hidden animations** (`live__stage`, all `live--still`, not shown since F001's renewal): they go. They hold words that are not true (AC-2), are measured on October's pictures, and nothing shows them. The pictures stay where they are.

**Tests**, in `Tests/MatterCoreTests/WebsiteLookTests.swift`, tagged `F003 AC-n`:

| Criterion | Test |
|---|---|
| AC-1 | Every picture in `site/assets/img` is used by the page; none is the file of 1 November (compared with `git show` before F003); Vision finds no cost, no "Auto mode", no AI but GPT-6.1 Sol. And the owner's look beside the app |
| AC-2 | The page's whole text, hidden parts too: none of "$0.", "Oct 12", "journal of cards", "Auto mode"; where "Sequoia 15" stands, "macOS 26" stands beside it; the first source the page names is not mail alone. And the owner's read |
| AC-3 | Every app picture has an alt text, none of AC-2's phrases in it. And the owner's read |
| AC-4 | The owner's look at each group |

**Not changed:** `site/styles.css` beyond what removing the hidden stages leaves unused, the film, the teasers, `numbers.html`, `Sources/`, `App/`.
