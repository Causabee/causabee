# F005 · The chat in two depths — What must be true

**Light** is what a quick question needs of one matter: its brief, what is open, its dates, people, notes and details, and what came in lately. **Deep** is the whole matter as the chat sees it today.

## Criteria

### AC-1 · A quick question goes light

- Given a matter with much in it
- When the owner asks a quick question about it — a task for tomorrow, a date, a note, who someone is, what comes next
- Then only the light part of the matter is sent, and the answer and its cards are the ones the whole matter would have given
- Holds for: every source of what came in; Mac, iPhone, iPad; with Pro and with an own key. Measured on **the full demo matter** — all the demo's invented matters merged into one, in a copy of the demo's store (below): a light question sends at most half the tokens it sends today. The demo's own matters are too small for a light text (the fullest about 2,500 tokens), so they stay deep, as today.

### AC-2 · A question that needs the whole matter goes deep

- Given a matter with much in it
- When the owner asks something only the whole matter holds — a number in a file, what someone wrote weeks ago, everything about one offer
- Then it is answered from the whole matter, as today
- Holds for: every source; Mac, iPhone, iPad; with Pro and with an own key

### AC-3 · "Not there" only after the whole matter

- Given a light answer that lacks something — it says it is not in the facts, or it needs an item the light part does not hold
- When the answer comes back
- Then the bee asks again with the whole matter before the owner sees anything, and shows only that answer. While it looks, the chat says so. It takes a few seconds longer; the owner agreed (Why, 11 November)
- Holds for: every source; Mac, iPhone, iPad; with Pro and with an own key

### AC-4 · Everything stays in reach

- Given an element of the matter the light part does not hold — an item that came in weeks ago, a done task, a file, a past date
- When the owner asks to see it, change it, put it away, move it or open it again
- Then the card acts on exactly that element, as today
- Holds for: every element the chat controls today (manifesto section 5); every source; Mac, iPhone, iPad

### AC-5 · A follow-up keeps the depth

- Given a conversation about one matter
- When the owner asks a follow-up
- Then it goes at the depth of the question before it, or deeper if it needs to, so the cache reads what was sent before; it never goes lighter in the same conversation
- Holds for: Mac, iPhone, iPad; with Pro and with an own key

### AC-6 · The same question, the same depth, on every device

- Given the same question about the same matter
- When it is asked on the Mac, the iPad or the iPhone
- Then it goes at the same depth
- Holds for: Mac, iPhone, iPad

### AC-7 · Tested before it ships

- Given the chat's pressure test on the demo's invented matters only, never real data
- When it runs with two depths and as today
- Then the two-depth answers are as good as today's: the same facts cited, the same cards, and no "not there" where today found it. A light depth on Terra goes in only if Terra passes the same test; otherwise light stays on Sol
- Holds for: a set of light and deep questions on the full demo matter, kept with the feature with its answers. The full demo matter is made by `matter-spike merge` in a copy of the demo's store: invented text only, never real data, never the demo the app shows.

### AC-8 · The ledger tells light from deep

- Given a chat request through the beeserver
- When it is written into the ledger
- Then its row says whether it went light or deep, and whether it was the second, deeper ask of AC-3
- Holds for: every chat request, from every device; an older build is counted as deep

## Must not change

Checked against what people have today: Beta 132, TestFlight 245, and the live beeserver.

- **The disguise:** only disguised text leaves the device, at both depths — `AssistantTests` ("nothing identifiable in what is sent"), `DisguiseFindingsTests`, `NameListTests`.
- **The chat controls everything a matter holds:** `ChatControlTests`, `AssistantAddTests`, `DateMatrixTests`, `SetAgainUITests`.
- **The cache:** the instructions and the matter marked for OpenAI's cache, a follow-up reading it — `PromptCacheTests`, `ChatCacheLiveTests`.
- **A pinned item and the chat across all matters:** they send what they send today — `AssistantTests` (focus), `MailLinksTests`, `LinkTests`.
- **Drafts in the owner's voice:** `RegisterTests`, `OfferedTimeTests`.
- **The table of jobs, the app's and the server's alike:** `AIJobTests`.
- **Pro, its allowance, the top-ups, the prices to the user.**
- **Without Pro and without an own key:** as today.
- **The tests:** all unit tests, the screen tests on iPhone, iPad and Mac.

## Open questions

None.
