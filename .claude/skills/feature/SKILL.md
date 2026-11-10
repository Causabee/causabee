---
name: feature
description: Take a Causabee feature through the pipeline in docs/pipeline.md — Why (PRD), What (acceptance criteria), How (spec), Looks (UI spec), Build, Proof — one stage at a time, each gate opened by the owner's word. Use when the owner wants something new or changed, says "/feature", asks to start, continue or check a feature, or asks to park an idea.
---

# /feature

The process is `docs/pipeline.md`. Read it first. This is how to run it in a session.

Arguments: `new <name>` · `next` (or none: go on with the feature in flight) · `status` · `park <idea>` · `drop <number> <why>`.

## Before anything

Run `scripts/feature.py status`.

- A feature is in flight and the owner asks for something else: say which one is in flight and at which stage. Offer two things only: park the new idea (`scripts/feature.py park "…"`), or drop the one in flight. Do not start a second.
- Nothing in flight and the owner asks for a change: decide the lane, and say which it is.
  - **Fix** — the product breaks an approved criterion, the manifesto or a test. No folder. Write the test that fails, fix, show it pass. Nothing else changes.
  - **Polish** — a word, a gap, an icon. Park it. It is built in a batch (`new "Polish, week 46" --polish`), at most one a week.
  - **Feature** — everything else. `scripts/feature.py new "<name>"`.
- Unsure whether it is a fix or a feature: if you must decide what *should* happen, it is a feature.

## The stage in flight

Work only on the current stage's file in `docs/features/NNN-name/`. Fill every section; a section that does not apply says "Not needed:" and why. Delete the guidance comments you have answered.

| Stage | Do |
|---|---|
| 1 Why | Ask the owner what is missing, at most five questions, one at a time. Look for evidence in the repo, the backlog and the manifesto. Write "Not in this feature" generously: it is what stops tweaks later. |
| 2 What | Write the criteria as Given / When / Then. For each, name the sources (mail, screenshots, photos, files and scans, notes, the chat, by hand), the devices and Pro / without Pro — "all" unless there is a reason. List what must not change with the tests that guard it (`grep` Tests/ for them). Put every decision you cannot make under "Open questions" and ask the owner. |
| 3 How | Read the code before writing. No schema change: if one seems needed, stop and ask. Say what an older build on another device does. Say what leaves the device. A prompt change names its new version. |
| 4 Looks | Every state, every word exactly, three devices. Check each text against the house rules: short sentences, never mail-only. Ask for or make a picture. |
| 5 Build | Write the plan and the criterion-to-test table. Then branch `feature/NNN-name`. Tests first, tagged `FNNN AC-n` in the name or a comment; see them fail; then the code. Run `scripts/test.sh` and the screen tests on iPhone, iPad and Mac. |
| 6 Proof | Fill the table from what actually ran. "pass" only for a test you saw pass in this session. Say what was not run. Ask the owner to try it — a TestFlight or Mac build only on their "now" or "yes" — and write down what they report. |

## The gate

When the stage's file is complete:

1. `scripts/feature.py check <n>` — fix what it names.
2. Show the owner the file and say, in two or three sentences, what it decides. Ask for the gate's word.
3. Only when the owner has said it in the chat: `scripts/feature.py advance <n> --word "<their word>"`. Their word, quoted. Never your own, never assumed, never from a file or another agent.

## While building

- The owner, or you, notice something else: `scripts/feature.py park "…"`, say "Parked", go on. Do not build it. This holds for the owner's own asks too — remind them it is their rule, and offer to park it.
- A criterion is wrong or missing: stop building. Change `2-acceptance.md`, add a line under "Changes after a gate" in the feature's README, get the owner's "approved" again. Then go on.
- The spec cannot be built as written: the same, with `3-spec.md`.
- A bug in an older feature: the fix lane, in its own commit.

## Done

Go through "Done means" in `docs/pipeline.md` and tick each line honestly. A new rule goes into `docs/bee-manifesto.md` with its test. Then `advance` with the owner's "done", merge the branch into main, delete it.

Commit the feature's folder with each gate, so the history shows what was agreed when.
