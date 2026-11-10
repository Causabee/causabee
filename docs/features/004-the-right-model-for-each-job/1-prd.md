# F004 · The right model for each job — Why

## The problem

Every job the bee does goes to GPT-6.1 Sol: reading what comes in, writing a matter's brief and next step, the chat, drafting a message. A heavy user costs about $26 a month that way, and a Pro month pays about $6. In the owner's own first Pro month the allowance of $4.50 was gone after four days.

The owner, 10 November: "I wouldn't like to release it with a €7 monthly fee and then only allowing for 3 days extensively using this." And: "I don't need to use 6.1 Sol always."

## Who has it

Everyone with Pro who uses Causabee every day — the people it is made for: a care matter, a move, a claim, many things coming in. Most of all the owner, who would release it to them and pays when the allowance runs out.

## What we know

From `docs/ai-cost-2026-11.md`, the ledger of 27 October to 10 November, the owner's own heavy use on three devices:

- $12.39 in all, $12.00 of it on Sol. **$0.87 a full day**, about **$26 a month**. 567 requests, about 2.2 cents each: about 6,400 tokens in and 840 out.
- About 60% of the cost is what is sent, 40% what comes back.
- Prices, from OpenAI's own pricing page (10 November): Sol $2 in, $10 out per million tokens; **Terra $1 and $5**; **Luna $0.10 and $0.50**, a twentieth of Sol; **Flex** half of any of them, in the same request, only slower. The research before this feature: `docs/ai-model-mixing-2026-11.md`.
- Estimates, not measurements: all on Terra about $13 a month; reading and digests on Luna with Flex, the brief on Terra with Flex, the chat on Sol, perhaps about $7 — if the jobs split as guessed.
- Research: a learned router or a cascade pays only with a sure signal of when a cheap answer is not good enough; our jobs are known in the code, so **a fixed model per job**, tested once per job, needs no router. A cache write now costs 1.25× and a cached read 0.05× of the input price, so the order of what a prompt sends matters.
- **The ledger cannot say which job a request was for.** No request carries its job. So the cheapest model cannot be chosen per job, nor the saving measured per job.
- **Its second rows count tokens twice** (parked for the fix lane): the dollars are right, token sums are not.

From the code:

- One model for everything: `Claude.Model.known = [gptSol]` (`Sources/MatterCore/Claude.swift`); the beeserver offers subscribers only `gpt-6.1-sol` (`server/beeserver/src/index.ts:38`).
- Whether Terra keeps the quality is untested. The owner chose Sol for its quality. `matter-spike pressure` records real answers and is the way to test a model on a job.

## The goal

Each job the bee does uses the cheapest model that keeps its quality — on Flex where it may wait, its prompt ordered for the cache — and the ledger shows what each job costs.

## Not in this feature

- The price of Pro, its allowance, or the top-ups.
- Batch, with answers a day later — a later feature, if this one does not save enough. (Flex, the same request at half the price, is in.)
- Shorter prompts or smaller contexts per job — a later feature, measured with what this one adds. (Putting what stays the same first, so the cache can read it, is in.)
- A learned router or a cascade between models for the same job.
- Another provider than OpenAI.
- A choice for the user: there stays one AI with Pro, and the app names the model each answer came from.
- The ledger's doubled token rows: the fix lane, parked.

## How we know it worked

Over a week of the owner's own daily use after the release, the cost per full day is at most half of today's $0.87, and the owner finds no answer, brief or sorting worse than before. The ledger shows that week per job.

## Principles it touches

- **11, said as it is:** the app and the website name the model that answered, as it is; where a job moves to another model, what is said moves with it.
- **Section 6, how we know she works:** a job moves to a cheaper model only after its pressure test shows the same quality.
- **12, everywhere the same:** the same job uses the same model on the Mac, the iPad and the iPhone.
