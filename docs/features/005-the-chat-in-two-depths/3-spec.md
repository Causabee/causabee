# F005 · The chat in two depths — How

## Data

Schema change: none

Nothing new is stored. The depth is chosen for each question when it is asked, and kept only in the conversation in memory (`Navigation.Turn` on the Mac and on the iPhone and iPad — plain structs, not SwiftData).

**One fact sheet, two texts.** `FactSheet.facts` builds the deep text as today, and beside it the light text, from the same pass, with **the same ids**: `T4` is the same task in both. So a card cites the same element at either depth, the turn's `refs` are one map (the deep one's), and nothing has to be renumbered when a light answer goes deep. `Facts` gets `light: String?` — nil where there is no light text (below).

**What the light text holds** (AC-1), of one matter:

| Part | Light | Deep, as today |
|---|---|---|
| The matter's name, other names, closed since | yes | yes |
| The owner's notes, the brief (`forFacts`) | yes | yes |
| Details (labels only), decisions | labels; the 5 newest decisions | all; 20 decisions |
| Open tasks, with due, waits for, note, links | yes, without the quote of where each came from | yes, with the quote |
| Worth knowing | the 10 newest | 30 |
| Done tasks | no | the 30 newest |
| Appointments | upcoming | upcoming and the 10 last |
| Deadlines | from today | all |
| Parties, with how to reach them | yes | yes |
| Files by name | the 10 newest | 40 |
| What came in | the 15 newest, with digests; the own words of the newest 3 | 120, with digests; the words of the newest 10 messages and of every screenshot, photo, scan and spoken note |

The light text ends with one line that says what is left out: "Not shown: older items, done tasks, past dates, older files. If the question needs any of them, or something is not here, say so in not_in_facts." That line is part of the facts, not the instructions, so the instructions stay the same bytes at both depths and the cache reads them for both.

**No light text** — the question goes deep as today — when: the chat asks about several matters at once (each is in brief already); something is pinned in hand (the sheet is focused already); or the light text would not be at most half of the deep one (a small matter — light saves nothing there).

## Which depth

`ChatDepth.pick(question:facts:earlier:) -> .light | .deep`, in MatterCore, with no AI and no clock, so the same question picks the same depth on every device (AC-6):

1. No light text → **deep**.
2. A follow-up (AC-5): at least the depth of the last turn about the same matter in this conversation.
3. **Deep** when the question holds a word of four letters or more that is in the deep text and not in the light one — a file's name, a party only in older items, an offer's word only an older item has. The same word matching as a pinned item's focus uses today (`FactSheet` `mentions`), over the words of the lines only the deep text has.
4. **Deep** when the question asks to search, in German or English: find, search, look up in, where does it say, what did … write, everything, all, history, number of, in the file, PDF, attachment — "such", "finde", "wo steht", "was hat … geschrieben", "alles", "alle", "Verlauf", "Nummer", "in der Datei", "Anhang", "Dokument", "Scan". The list lives in one place, with a test for each word.
5. Otherwise **light**.

**Going deeper** (AC-3): when a light answer comes back with `not_in_facts`, or cites an id the light text does not show, it is not shown. The same question goes again with the deep text and the same earlier turns; only its answer is shown. One deeper ask at most. The turn's step says so while it looks (the words: stage 4).

## Sync and other devices

Nothing syncs that did not before: the depth lives in the conversation on one device. What the owner takes from an answer — a task, a note, a date — syncs as today.

An older build on another device asks as today, deep, and names its job "chat". The beeserver counts it as deep (AC-8).

## Privacy

A light question sends less of the matter; it sends nothing new. Both texts go through the same disguise as today: `AssistantAsk.prepare` disguises the text that goes, light or deep, and the deeper ask is prepared again, the same way. Web addresses go as `[Link n]`, as today. Nothing leaves the device without the owner asking a question, as today.

## The AI

- **The instructions do not change:** `AssistantPrompt.system` stays `assistant-v24`, the schema too. What is new is in the facts: the light text and its last line. So the cache reads the instructions for every chat question, light or deep, on every matter, within 30 minutes.
- **Two jobs more, in F004's table** (`AIJob` and `server/beeserver/src/jobs.json`, compared by `AIJobTests`):
  - `chat-light` — a light question. Sol, effort medium, no Flex, to start. `testing: ["gpt-6.1-terra"]`.
  - `chat-deeper` — the second, deeper ask of AC-3. Sol, effort medium, no Flex, like `chat`.
  - `chat` stays the deep question: Sol, effort medium, no Flex.
  The ledger's `job` column says which (AC-8); no migration, it is text already.
- **The pressure test** (AC-7), only on the demo's invented matters, with `matter-spike pressure` (it refuses a store whose owner is not Mara Voss):
  - The cases, in `docs/features/005-the-chat-in-two-depths/tests/cases.json`: on each demo matter, five quick questions (a task for tomorrow, a date, a note, who is someone, what next) and five that need the whole matter (a number in a file, what someone wrote weeks ago, a done task, a past date, everything about one item).
  - Each runs as today (deep) and with two depths. Kept: what was sent, its tokens, the depth picked, whether it went deeper, the answer's lines and cards.
  - Passes when every two-depth answer cites the same facts and offers the same cards as today's, and no answer says "not there" where today's found it. Where they differ, the owner reads both without knowing which is which (as F004's briefs), and finds the two-depth one no worse.
  - Then the light questions once more on Terra. `chat-light` moves to Terra only if it passes the same, and then what Settings and causabee.app say about the models moves with it (principle 11; `AIJob.said`, its words at stage 4).
- **The measure of AC-1:** the light text of the demo's fullest matter, sent, is at most half the tokens of its deep text. A unit test counts characters on the demo's seed; the pressure test's report has the tokens.

## Calendar and Reminders

Not touched.

## When it fails

- **The light ask fails** (no network, the allowance used, a server error): the owner sees the error as today. No deeper ask follows a failure.
- **The deeper ask fails:** the owner sees the error as today. The light answer that lacked something is not shown in its place: it might say "not there" when the matter has it (AC-3).
- **The deeper answer lacks it too:** it is shown, with its `not_in_facts`, as today — the whole matter was looked at.
- **Stopped while it looks deeper:** stopped as today; nothing of either answer is shown.
- **The beeserver from before this feature** does not know `chat-light` or `chat-deeper` and would refuse them. So the server goes out first, as F004's did; the app after it.

## Where in the code

Shared by the Mac, the iPhone and the iPad (MatterCore):

- `Sources/MatterCore/Model/Assistant.swift` — `FactSheet.facts` builds the light text beside the deep one, with the same ids; `Facts.light`. `AssistantAsk.ask` takes the depth, asks, and asks once more deep when the light answer lacks something; it returns the depth it answered at and whether it went deeper. A new step, `AssistantAsk.Step.lookingDeeper`.
- `Sources/MatterCore/Model/ChatDepth.swift` — new: `ChatDepth.pick`, its word lists.
- `Sources/MatterCore/AIJob.swift` and `server/beeserver/src/jobs.json` — `chat-light`, `chat-deeper`.
- `Sources/MatterSpike/main.swift` — `pressure` runs a case at both depths and writes the depth, tokens and whether it went deeper.

Per app, the same small change in each:

- `Sources/Causabee/Conversation.swift` (Mac) and `Sources/CausabeePhone/AssistantSheet.swift` (iPhone, iPad) — pick the depth, pass it to `ask`, keep it in the turn for the next follow-up; show the new step.
- `Sources/Causabee/CausabeeApp.swift` and `Sources/CausabeePhone/Navigation.swift` — `Navigation.Turn` gets `depth`, in memory only.

Order of release: the beeserver first (`npm run deploy`), then the apps.
