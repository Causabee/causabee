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
- Prices, from published pages, not confirmed with OpenAI: Sol $2 in, $10 out per million tokens; **Terra $1 and $5**; batch about half of either.
- Estimates, not measurements: all on Terra about $13 a month; Terra and batch where waiting is fine, perhaps $8–10.
- **The ledger cannot say which job a request was for.** No request carries its job. So the cheapest model cannot be chosen per job, nor the saving measured per job.
- **Its second rows count tokens twice** (parked for the fix lane): the dollars are right, token sums are not.

From the code:

- One model for everything: `Claude.Model.known = [gptSol]` (`Sources/MatterCore/Claude.swift`); the beeserver offers subscribers only `gpt-6.1-sol` (`server/beeserver/src/index.ts:38`).
- Whether Terra keeps the quality is untested. The owner chose Sol for its quality. `matter-spike pressure` records real answers and is the way to test a model on a job.

## The goal

Each job the bee does uses the cheapest model that keeps its quality, and the ledger shows what each job costs.

## Not in this feature

- The price of Pro, its allowance, or the top-ups.
- Batch or delayed processing — a later feature, if this one does not save enough.
- Shorter prompts or smaller contexts sent per job — a later feature, measured with what this one adds.
- Another provider than OpenAI.
- A choice for the user: there stays one AI with Pro, and the app names the model each answer came from.
- The ledger's doubled token rows: the fix lane, parked.

## How we know it worked

Over a week of the owner's own daily use after the release, the cost per full day is at most half of today's $0.87, and the owner finds no answer, brief or sorting worse than before. The ledger shows that week per job.

## Principles it touches

- **11, said as it is:** the app and the website name the model that answered, as it is; where a job moves to another model, what is said moves with it.
- **6, how we know she works:** a job moves to a cheaper model only after its pressure test shows the same quality.
- **12, everywhere the same:** the same job uses the same model on the Mac, the iPad and the iPhone.
