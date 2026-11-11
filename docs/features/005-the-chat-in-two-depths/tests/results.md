# F005 · The pressure test — results

`matter-spike pressure` on **the full demo matter**: all 16 of the demo's invented matters merged into one (`matter-spike merge`), in a copy of the simulator's demo store — invented text only, never real data. 44,783 characters in all; its light text 21,709 (48%). The cases: `cases.json` — 9 quick questions, one quick question with a follow-up, 10 that need the whole matter. Each asked as today (`today.json`), with two depths on Sol (`two-depths.json`), and the quick ones with two depths and Terra for light (`two-depths-terra.json`), in `answers/`. 11 November 2026. Cost of the whole test: $0.36.

## AC-1 · A quick question goes light, and sends at most half

| | Today | Two depths |
|---|---|---|
| What a quick question sends of the matter | 44,400 characters | 21,200 — **48%** |
| The first question of a conversation (q01, the cache written fresh) | $0.046 | **$0.019** — 41% |
| The ten quick cases, one after the other | $0.111 | $0.102 — of it $0.035 for q05, the first to write the whole matter to the cache in that round |

Each quick case after the first read the matter from the cache, as a follow-up does since Beta 132, so after the first they cost little either way. The saving is in the first question: what the owner pays most often, once per conversation.

Picked: 9 of the 10 quick questions went light. One, "Who wrote about the key box by the door?", went deep because "wrote" asks what was written; answered the same in both rounds.

## AC-2 · A question that needs the whole matter goes deep

7 of the 10 went deep at once: by a search word (number, find, everything, wrote) or a word only the whole matter has (Sunrise, assessor, tiles, care level).

## AC-3 · "Not there" only after the whole matter

The 3 others went light first, lacked something, and were asked again deep: "What happened in the parking-lot accident?", "Which offers did the banks make?", "How much is the repair estimate for my car?". Each was answered from the whole matter, with the same facts as today: the claim number, €1,840, the three banks' offers. The light answer was not shown.

**No answer said "not there" where today found it.** The three that said something is missing — the insurance offer's number, the assessor's findings, which tiles — said so in both rounds, after the whole matter.

## AC-7 · As good as today's

| Case | Same facts | Same cards |
|---|---|---|
| q01, q03, q04, q06, q08 — a task, a note, a reminder, the move, a date change | yes | yes |
| q05, d01–d10 — at depth deep, or deeper | yes | yes |
| q02 "What's next?", q10 "What's next?" | yes | **fewer**: one "mark done" card where today offered three |
| q07 "What do I have to do this week?", q09 "Is anything due tomorrow?" | yes, worded differently | yes |
| q10b "And after that?" | the same days; it begins with 15 November where today began with 14 | yes |

The difference that counts: on "What's next?" the light answer suggested marking one task done where today suggested three. The two it left out — Sam's guest list came in, the care rota is agreed — are known from items older than the 15 newest, which the light text does not hold. Sol asked twice the same way also varies in what it offers; whether this is worse is the owner's to say, blind: `blind.md`, the key in `blind-key.json`.

## Terra for quick questions — does not pass

| | Sol | Terra |
|---|---|---|
| The ten quick questions | $0.102 | $0.040 |
| Time, longer answers | 6–15 s | 13–22 s |

Below the bar:
- q08 "Add a task: confirm my bank details by Monday": Sol moved the task that is there; **Terra added a second one**.
- q07: Terra offered a "mark done" card with no text.
- q02, q10: Terra offered no "mark done" card at all.

So `chat-light` stays on Sol, and nothing the app or causabee.app says about the models changes.

## Also seen

- Round 2 disguised more names than round 1 ("Mara", "Helga" became stand-ins): the test's list of names learned them in round 1. That is the disguise learning as it does in the app; it is not F005's, and it changed no answer.
