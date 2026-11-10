# How a feature is built

Causabee was built by trying and correcting. That was fast, and it left loose ends: in the screens, in the data, in the code. From 10 November 2026 a feature goes through six stages. Each stage is one short file. Each ends at a gate the owner opens with a word.

The manifesto ([bee-manifesto.md](bee-manifesto.md)) says what the bee must do. This says how a change gets there.

## The rules

1. **One feature in flight.** The next one starts when this one is done or dropped.
2. **Nothing is built before its acceptance criteria are approved.** No code, no prompt, no screen.
3. **A finished feature is closed.** A change to it is a new feature, with its own file. Never a tweak.
4. **An idea in the middle of work is parked.** One line in [backlog.md](backlog.md). Not built now.
5. **Every acceptance criterion has a test.** No test, not done.
6. **The owner opens each gate.** With a word in the chat: "go", "approved", "yes". Nobody else does.

## Three lanes

| Lane | When | Path |
|---|---|---|
| **Feature** | Something new, or something that should work differently. | All six stages. |
| **Fix** | The product does not do what an approved criterion, the manifesto or a test promises. | A test that fails first. Then the fix. Then the test passes. No new behaviour. No folder. |
| **Polish** | Small things from the backlog: a word, a gap, an icon. | Collected, not done one by one. At most one batch a week, through the six stages, kept short. |

If a fix needs a decision about what *should* happen, it is not a fix. It is a feature.

## The six stages

| # | Stage | File | It answers | Gate: the owner says |
|---|---|---|---|---|
| 1 | Why | `1-prd.md` | What problem, for whom, what is out, how we know it worked. | "go" |
| 2 | What | `2-acceptance.md` | What must be true when it is done. What must not change. | "approved" |
| 3 | How | `3-spec.md` | Data, sync, privacy, prompts, failures. | "approved" |
| 4 | Looks | `4-ui-spec.md` | Every screen, every state, every word, on every device. | "approved" |
| 5 | Build | `5-plan.md` | The steps, and the test for each criterion. Then the code. | "built, show me" |
| 6 | Proof | `6-test-report.md` | Each criterion, its test, its result. The owner's own try. | "done" |

Claude drafts each file. The owner reads it, corrects it, and opens the gate. A stage that does not apply says so in one line, with the reason ("No screen changes: the sync only").

### 1 · Why (PRD)

One page. The problem in the user's words. Who has it. What we know and how. What this feature will not do. One measure of success. Which principles of the manifesto it touches.

Done when someone who was not in the conversation understands why this is worth a week.

### 2 · What (acceptance criteria)

Numbered: AC-1, AC-2 … Each as *Given, When, Then*. Each says where it holds:

- **every source** — mail, screenshots, photos, files and scans, notes, the chat, by hand. Or it names the ones it holds for, and why only those.
- **every device** — Mac, iPhone, iPad.
- **with Pro and without.**

And a list of what **must not change**, with the tests that guard it.

Done when each criterion can be answered yes or no by looking.

### 3 · How (spec)

- **Data.** Which models, which fields. The schema does not change. If it must, that is the owner's decision, written here, before anything else.
- **Sync.** What a second device sees, and when. What an older build does with it.
- **Privacy.** What leaves the device. How it is disguised. What is never sent.
- **The AI.** Which prompt changes, its new version, how it is pressure-tested.
- **Calendar and Reminders.** What is written there, what is read back.
- **When it fails.** What the user sees. Nothing fails silently.

### 4 · Looks (UI spec)

- Each screen and each state: empty, one item, many, long text, an error, without Pro.
- The exact words. Short sentences. Never mail-only.
- Mac, iPhone, iPad: what is the same, what the layout changes.
- Undo. Dark mode. Large text. VoiceOver names.
- A picture: a Figma frame or a sketch.

### 5 · Build

First the plan: the steps, and a table that gives every criterion its test. Then, on a branch `feature/NNN-name`:

1. The tests, written first, each tagged `FNNN AC-n` in its name or comment. They fail.
2. The code. They pass.
3. `scripts/test.sh`, the screen tests on iPhone, iPad and Mac.

The plan is followed. If it cannot be, see "When something comes up".

### 6 · Proof

A table: criterion, test, result. The screen tests' devices. For the AI: the pressure test's report. Then the owner tries it on their own device, on a TestFlight or Mac build made for that, and says what they saw.

"Must not change" is checked against what people have today — the live website, the released build — never against an earlier build of this feature. (F001, 10 November: the film was compared with its own first render, and its ticks were off for everyone; the owner found it.)

Done when every criterion is "pass" and the owner says "done".

## When something comes up

| While building, … | Do |
|---|---|
| you see something else to improve | Park it: `scripts/feature.py park "…"`. Go on. |
| a criterion turns out wrong or missing | Stop. Back to stage 2. Change it, the owner approves again, the change is noted in the feature's README. |
| the spec cannot be built as written | Stop. Back to stage 3. Same. |
| an older feature has a bug | Fix lane: a failing test, the fix, done. Apart from this feature. |
| the feature grows | Cut it. What is left out becomes a line in the backlog. |

## Done means

- [ ] Every criterion has a tagged test, and it passes.
- [ ] What must not change did not: all unit tests, the screen tests on three devices.
- [ ] The words are the spec's words.
- [ ] A new rule found on the way is in the manifesto, with its test.
- [ ] The release notes have its line.
- [ ] The owner tried it and said "done".
- [ ] It is merged into main. The branch is gone.

## Releases

A release carries finished features and fixes. Nothing half-built.

- **The owner's own builds:** as often as wanted, to try a feature at stage 6. TestFlight still only on "now" or "yes".
- **A public build:** at most once a week, after two days of the owner's own use.

## The commands

```sh
scripts/feature.py new "Name of the feature"   # the next number, its folder, its six files
scripts/feature.py status                      # every feature and its stage
scripts/feature.py check 7                     # is stage's file complete? criteria covered by tests?
scripts/feature.py advance 7 --word "approved" # the gate, opened by the owner's word
scripts/feature.py park "The gap under the date is too small"
scripts/feature.py drop 7 "Not needed after all"
```

In Claude Code, `/feature` walks through the same stages and asks the questions each one needs.
