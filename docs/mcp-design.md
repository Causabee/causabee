# Causabee as an MCP server — design note

Status: idea, not started (6 November 2026). Written to start the work from; nothing here is decided
beyond the direction marked **Recommendation**.

## What it is for

Let an assistant the owner already uses — Claude Desktop, Claude Code, another MCP client — work
with their matters:

- "What is open in the move?" · "What is due this week, across everything?"
- "What did the insurer say about the bath seat?"
- later: "Add a task to call Sunrise on Monday."

Causabee has no server and no account. The MCP server therefore runs **on the owner's Mac**, as a
local process the client starts (stdio). Nothing goes to a Causabee server, because there is none.

## Where it runs and how it reads

- **Mac only.** iPhone and iPad have no place for a local MCP process; they can follow later through
  App Intents (Shortcuts, Siri), which the same work prepares.
- **Through the app, not the store file.** Two processes writing one SwiftData store risk conflicts and
  iCloud trouble. The MCP process asks the running app (a local socket or XPC), or the app exposes
  App Intents and the MCP process calls those. Read-only access to the store directly is possible as a
  first spike, never writes.
- **Read-only first.** Writing (add a task, a note, mark done) comes after the read side has proved
  itself, and each write is shown in Causabee like anything else the owner did.

## Tools (first cut)

| Tool | Returns |
|---|---|
| `list_matters` | open matters: name, next step, counts of open tasks and dates |
| `get_matter` | summary, next step, open tasks, dates, Good to know, details, parties |
| `search` | matches across matters: tasks, mail digests, notes, file names |
| `get_mail` | one mail's digest and text, by id from `get_matter` / `search` |
| `get_file_text` | the extracted text of a file — never the file itself |
| `whats_due` | tasks and dates across all shared matters for a range of days |

Ids are opaque and only valid for the shared matters.

## Privacy

Inside Causabee everything is pseudonymised before it reaches an AI: names, addresses and numbers
become placeholders such as `[Person A]`, and Causabee puts the real names back before the owner reads
the answer. Over MCP that last step is missing — the client shows the model's answer directly — and
whatever the server returns, the model sees too. So there is no "real names for the owner only".

Files are not the hard part: Causabee already extracts a PDF's or a scan's text on the device and
sends only text. The MCP server does the same — `get_file_text`, run through the same pseudonymiser
when the matter asks for it. No raw file ever leaves.

Options:

1. **Per-matter opt-in, real names, text only.** In Settings the owner picks which matters an
   assistant may see. Unshared matters do not exist for it. Clear, readable answers; the owner
   decides per matter.
2. **Pseudonymised with readable aliases.** Each person gets a stable made-up name ("Anna Berger").
   Answers read naturally, but the owner has to know who is who, or an answer misleads.
3. **Pseudonymised with placeholders.** Safest, least pleasant: fine for "what is overdue", poor for
   "draft my reply to the insurer".
4. **A local model.** Nothing leaves the Mac, so nothing needs disguising — depends on the owner's
   setup.

**Recommendation:** 1 and 3 together. Each matter is off, shared with real names, or shared
pseudonymised (placeholders). Off by default; text only, never files; every request logged in
Causabee, so the owner can see what an assistant looked at.

## Open questions

- Socket/XPC to the running app, or App Intents as the one door for MCP, Shortcuts and Siri?
- What happens when the app is not running — start it, or answer "Causabee is closed"?
- Does a pseudonymised matter keep the same placeholders as the in-app assistant (same mapping),
  so answers from both line up?
- How the owner sees the log of what was read, and turns sharing off again.
- Writes: which first, and how the owner confirms them.
