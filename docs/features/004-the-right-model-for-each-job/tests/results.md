# F004 · The tests of each job — 10 November 2026

`matter-spike jobs` on the demo's invented matters only: 93 items (78 mails, 7 screenshots, 6 files, 2 photos), 16 matters. Each job with the prompts, the disguise and the job header the app sends; Sol twice, to see how far it differs from itself. Cost: $4.17 in all, with a first trial, Luna again, Haiku, and Sol at low effort.

## Reading what comes in — stays on Sol

| | Another matter than Sol's | Sol's tasks and dates found | Cost of 93 items |
|---|---|---|---|
| Sol, run again | 3 | 95.4% | $0.68 |
| Terra | 7 | 85.1% | $0.36 |
| Luna | 2 | 56.3% | $0.05 |
| **Bar (AC-3)** | **none** | **at least 95%** | |

- Sol itself is not the same every time: 3 items of 93 went elsewhere, or nowhere, on its second run.
- Terra: more than twice Sol's own differences; it leaves clear items without a matter (the gym contract, the bath-seat prescription, the travel insurance) and makes up matter names.
- Luna: places items as well as Sol does, but writes 27 of its 47 tasks in German for English sources, against the rule "never translate". Most of its misses are Sol's task in the other language.

`read.md` lists every difference; `read-sol-against-sol.md` Sol's own.

**Luna again, with each item's language told** (the owner's go, 10 November): the reading prompt now says, with each item, "The email is written in English. Write its to-dos … in English." Sol and Luna read the 93 items again.

| | Another matter than Sol's | Sol's tasks and dates found | German tasks for English items |
|---|---|---|---|
| Sol with the line, against Sol before | 4 | 95.4% | — |
| Luna with the line | 2 | 79.6% | 3 of 47 (before: 27 of 47) |

The line fixes Luna's language and does not change Sol beyond its own spread. Luna still misses real tasks — "arrange help with showering and shopping" after the hospital stay, "send the address and door code" for the dinner — and gave physio on 6 October where the item says 2 October. Below the bar: reading stays on Sol. `read-language-told.md`.

**Claude Haiku 5.5, the owner's idea, 10 November** — Luna's price ($0.10 in, $0.50 out), Anthropic's API with the owner's key, the same prompt with the language line, the same disguise, the demo only:

| | Another matter than Sol's | Sol's tasks and dates found | Cost of 93 items |
|---|---|---|---|
| Haiku 5.5 | 7 | 69.3% | $0.07 |

Haiku keeps the language (no German task for an English item) and finds things Sol does not — the €2,000 deposit for the wedding venue, the decision on the moving quote — but leaves clear items without a matter (the dinner invitation, the building insurance, the rate comparison) and misses tasks Sol finds (help with showering after the hospital stay, the address and door code for the dinner). Below the bar. `read-haiku.md`.

**Sol thinking less** (the owner's go, 10 November): reading on Sol with `reasoning.effort` "low", against Sol as the app sends it today (no effort set), same prompt, same 93 items.

| | Another matter than Sol's | Sol's tasks and dates found | Cost of 93 items | Seconds an item |
|---|---|---|---|---|
| Sol, as today | — | — | $0.69 | 9.1 |
| Sol, effort low | 1 | 93.2% by the script; 95.5% read by hand | $0.61 | 5.0 |

Two of the six the script counts as missed are Sol's task in other words ("Vote on approval of the draft management contract" for "Approve the management contract"; "Send the meter reading and new address" for "Send the new address"). Left: one task of two on one item (physiotherapy after the hospital stay), a reply in a group chat, a key code the landlord sends, one expected date. Sol run twice differs from itself by as much (3 items, 95.4%). `read-sol-low-effort.md`.

The owner, 10 November: yes — **reading runs on Sol with effort "low"**, kept in the table beside the model (`jobs.json`, `AIJob.effort`).

## Digests — the same facts

Terra and Luna: no number or date that Sol's digest does not have, in 78 digests; the wording differs, the facts do not (`digest.md`). Luna wrote one digest in German for an English mail. **Digests move to Terra**: the same facts, and no word in another language.

## The brief — the owner's judgement, blind

`briefs-blind.md`: 16 matters, A and B, one Sol's and one Terra's; the key, `briefs-key.json`, was kept apart until the owner had judged.

The owner, 10 November: "they both look correct to me … They are meaningful. It's not that I would say one or the other is a bad or good. So I don't see the big difference here." Terra is no worse: **the brief moves to Terra**, at half of Sol's price ($0.10 against $0.21 for 16 briefs).

## Answers

`answers/`: every answer, as it came back. Demo data only.
