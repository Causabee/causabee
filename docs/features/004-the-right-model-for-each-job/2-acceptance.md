# F004 · The right model for each job — What must be true

## Criteria

### AC-1 · Every request says its job

- Given a request the app sends to the AI through the beeserver
- When it is written into the ledger
- Then its row says which job it was for — reading what comes in, a digest, the brief and next step, the chat — beside its model, tokens and cost; and the owner can ask the ledger what each job cost, per day
- Holds for: every request, from the Mac, the iPad and the iPhone; with Pro. A request from an older build without its job is counted as "unknown", not refused.

### AC-2 · Each job has its model, in one place

- Given the table of jobs and models
- When any device asks for a job
- Then it uses that job's model, and the server refuses a model the table does not give that job
- Holds for: every job, on every device; the same table in the app and on the server

### AC-3 · A job moves to a cheaper model only after its test

- Given a job and a cheaper model for it
- When the job's pressure test runs on both, on the demo's invented matters only — never real mail
- Then it moves only if the cheaper model's answers are as good as Sol's:
  - **reading what comes in:** every item in the same matter as Sol puts it, and at least 95% of the tasks and dates Sol finds, none invented
  - **digests:** the same facts as Sol's, nothing invented
  - **the brief and next step:** the owner, reading both without knowing which is which, finds the cheaper one no worse
  - **the chat:** stays on Sol in this feature
- Holds for: every job that moves; the results are kept with the feature, the answers too

### AC-4 · What may wait, waits for half the price

- Given a job that runs in the background — reading what comes in, digests, the brief
- When it is sent
- Then it goes on Flex, at half the price; and when Flex answers "busy", the same request goes again on the normal tier, and the owner sees nothing but the result
- Holds for: those jobs on every device; never the chat, where someone waits

### AC-5 · What stays the same is sent first

- Given a job's prompt
- When it is sent
- Then what is the same for every request of that job — the instructions, the schema — comes first, and what changes comes last, so the cache can read it
- Holds for: every job. Measured in the ledger: the share of what is sent that is read from the cache, per job, rises from about a fifth.

### AC-6 · Said as it is

- Given what the app and the website say about the AI
- When a job uses another model than Sol
- Then the app names, beside each answer or brief, the model that wrote it, and the website no longer says one model does everything
- Holds for: the Mac, the iPad, the iPhone and causabee.app

## Must not change

Checked against what people have today: Beta 128, the TestFlight build, and the live beeserver.

- **The disguise:** every job, on every model, gets only disguised text, as now.
- **Pro and its allowance, the top-ups, the prices to the user.**
- **Without Pro:** Apple's model on the device, or threads and senders, as now.
- **The chat:** Sol, its answers as now.
- **The tests:** all unit tests, the screen tests on iPhone, iPad and Mac; `SaidAsItIsTests`.
- **The ledger's money:** what a request costs and what is taken from the allowance, as now — only its job is added.

## Open questions

None.

**Decided by these criteria, for the owner's approval:** the quality bar of AC-3 (same matter every time; 95% of tasks and dates; nothing invented; the brief judged blind by the owner). Changed at the gate if the owner wants it stricter or looser.
