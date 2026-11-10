# Causabee

# ⚠️ CAUSABEE IS NOT A MAIL APP. MAIL IS ONLY ONE SOURCE. ⚠️

**Everything that comes in counts the same:**
**mail · screenshots (WhatsApp, chats) · photos · files and scans · notes · what is said in the chat · tasks and dates added by hand.**

- Never describe what the bee does as "reads mail", "after new mail", "from the mail". Say **what comes in**, **new information**, **a source**.
- In UI text, prompts, comments, commit messages, docs and answers: name all sources, or none — never mail alone.
- Before writing "mail", ask: does this hold only for mail? If not, don't write mail.
- Causabee is about **matters**, not a mailbox.

The owner has said this since the first day. Getting it wrong again is not acceptable.

## The bee's manifesto

**Read [docs/bee-manifesto.md](docs/bee-manifesto.md) before changing what the bee does or shows. Check every change against its principles.**
**Every new rule found with the owner goes into the manifesto, with its test, in the same change as the fix.**

## How a feature is built

**Read [docs/pipeline.md](docs/pipeline.md) before changing what the product does or shows.** Trial and error left loose ends; from 10 November 2026 every change takes a lane:

- **Feature** — new or changed behaviour: six stages in `docs/features/NNN-name/` (Why, What, How, Looks, Build, Proof). No code before the acceptance criteria are approved. One feature in flight.
- **Fix** — the product breaks an approved criterion, the manifesto or a test: a failing test first, then the fix. No new behaviour.
- **Polish** — words, gaps, icons: parked in `docs/backlog.md`, built as a batch, at most one a week.

- The owner opens each gate with a word in the chat. Never advance a stage without it.
- A finished feature is closed. A change to it is a new feature, never a tweak.
- Something noticed in the middle of work — by the owner too — is parked (`scripts/feature.py park "…"`), not built. Say so, and go on.
- `/feature` runs the stages; `scripts/feature.py status` says where things stand.

## Standing rules

- Causabee takes the mental load: short, precise sentences, few words.
- TestFlight only on "now" or "yes".
- Never change the SwiftData schema.
