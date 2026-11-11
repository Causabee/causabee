# F005 · The chat in two depths — Why

## The problem

Every question in the chat sends the whole matter: every open task, the last 30 done, every file's name, up to 120 items that came in with their digests, and the words of the newest messages and of every screenshot, photo, scan and spoken note. "Make a task for tomorrow" sends as much as "find the number of the offer in that PDF". The first question about a matter costs about $0.05, and a matter that grows costs more.

The owner, 11 November: "Sometimes chat is only about create a task for tomorrow, and I don't need so much deep context. … But when I'm asking for look into a special PDF or look into the whole matter and find the … number of a certain offering … it has to look into and make sense out of the whole thing." And: "My expectation is when the matter is filled with a lot of stuff, you will use chat a lot."

## Who has it

Everyone with Pro who talks to the bee: most questions are small — a task, a date, a note, who someone is — and a few need the whole matter. Most of all a matter that is full: a care matter with months of messages and screenshots, a move, a claim.

## What we know

From the ledger since F004 and the cache fix (11 November, the owner's own use):

- **The chat is the dearest job:** 6 of 32 requests, $0.18 of $0.41 — 45% of the cost. A chat request sends about 15,600 tokens on average; a brief about 7,600.
- **The first question of a conversation: $0.048.** About 14,000 tokens of the matter and 4,500 of instructions, on Sol at $2 per million, written to the cache at 1.25×; the answer, about 200 tokens, is $0.002.
- **A follow-up: $0.0045** since Beta 132 — it reads the matter from the cache. So the cost that is left is the first question, and it grows with the matter.
- The fact sheet has caps (120 items, 30 done, 40 files), except the words of screenshots, photos, scans and spoken notes: up to 1,500 characters for each of them among the 120. A matter of WhatsApp screenshots can send 20,000 tokens or more. (`FactSheet.facts`, `Sources/MatterCore/Model/Assistant.swift`.)
- The instructions (`AssistantPrompt.system`, about 4,500 tokens) cover all 26 kinds of card, for every question.
- The answer can already say what it did not find: `not_in_facts`. And it has a card to look further: `look_up`.

Guesses, not measured:

- Most questions need only the brief, what is open and what came in lately: perhaps 2,000–3,000 tokens of the matter. Then the first question costs about $0.01.
- Terra, at half of Sol, may answer the light questions as well. Untested for the chat; F004 kept the chat on Sol for its quality.
- How many questions are light. The ledger stores nothing of what was asked, and should not.

## The goal

A quick question costs a fraction of today's, and a question that needs the whole matter is still answered from the whole matter — without the owner choosing which.

The owner, 11 November, asked whether a deep question may take a few seconds longer when the light answer falls short: "Yes, go."

## Not in this feature

- A button or a switch for the depth. The bee picks it, and goes deeper on its own when the light answer lacks something (principle 9, and "the bee carries the mental load").
- The follow-up's cost: fixed already (the cache, Beta 132).
- Keeping the cache longer than 30 minutes, or warming it before a question.
- The chat with a file's own text (parked: the chat with a PDF lacks the file's text). Deep means the whole matter as the chat sees it today, not more.
- A smaller fact sheet for the brief, the summary or the next step. Only the chat.
- Another provider, or a model outside F004's table. Terra is tried only as a model already there.
- The price of Pro, its allowance or the top-ups.
- New cards or new things the chat can do.

## How we know it worked

Over a week of the owner's own daily use after the release, the first question of a conversation costs on average at most half of today's $0.048, and the owner finds no answer worse than before — none that says something is not there when it is in the matter. The ledger shows it: per chat request, light or deep.

## Principles it touches

- **Section 5, the chat:** "She answers from what is in your matters … and says when it isn't there only after looking in them." A light answer never says "not there": it goes deep first.
- **Section 5, you control everything from the chat:** every element stays reachable. A question about an element the light sheet does not hold goes deep.
- **9, less, not more:** what is sent for a question is what it needs.
- **11, private:** less leaves the device for a light question; nothing new leaves it.
- **12, everywhere the same:** the same question picks the same depth on the Mac, the iPad and the iPhone.
- **Section 6, how we know she works:** a light depth, and Terra if it is tried, only after a pressure test on the demo's matters shows the same answers.
- New rule, to the manifesto at stage 5: *A quick question is answered from what it needs; "not there" only after the whole matter.*
