# The record: everything linked, read or kept, browsable

Concept and solution design · 19 October 2026 · branch `record-concept`

## What you asked for

1. Mail, files, tasks and dates linked both ways, everywhere: a task opens its source, and a record item shows which tasks and dates came from it.
2. A clear visual divide between what Causabee **read** (and can answer from) and what is only **kept** (stored, never read).
3. A better way to browse the record: more of each item's text, and ways to sort and filter.
4. See which mails are still unread.

## How it works today

| Area | Today | Problem |
|---|---|---|
| Task → source | Mac: "from the mail of Oct 8" opens the mail **in Apple Mail** (or the file). iPhone/iPad: the same line is **plain text, not tappable**. | You leave the app to check a source; on iPhone/iPad you can't check it at all. |
| Dates → source | Mac: a "Source" link opens Mail. iPhone/iPad: none. | Same. |
| Record item → tasks | Nothing. The data is there (every task and date keeps the Message-ID of the mail it came from), but no view shows it. | You can't tell which mails produced work and which were only information. |
| Read vs kept | A mail's body is read. Files added with **+ File** are read (they get a digest). Files from **Files or a folder** are kept, not read. **Mail attachments are not read.** All of them look the same in the record. | You can't tell what the assistant knows from what is only stored. |
| Text per item | A conversation shows its subject once; each mail in it shows sender, date and a 2–3 sentence digest, cut at 3 lines. Files show their name, sender and size. | Too little to recognise a mail without opening it. |
| Browsing | One menu: Everything / Mail / Files / Details / Links. Newest first, by month; filter by one person from People. ⌘F searches the page. | No sort, no "only what has tasks", no "only what wasn't read", no unread. |
| Unread | Causabee reads mail with `BODY.PEEK` so it never marks anything read, and it never asks the mailbox for read flags. | Nothing to show. |

## Principles

- **One record item, one look.** A mail, a file, a scan, a screenshot, a link: each is a card of the same build — what it is, who and when, what it says, what came from it.
- **Links are shown where you are, and open in place.** A source opens inside Causabee first; Mail or the file is one step further, never the first.
- **"Read" is a promise.** Only what Causabee actually read is styled as read. Everything else says plainly that it is stored only.
- **Read-only towards the mailbox stays.** Unread is shown, never changed: Causabee does not mark mail read or unread.
- **No new sync burden.** Links are computed from what is already stored and synced; only one small field is added.

## The solution

### 1. Links both ways

**From a task, a date or a deadline to its source**

- The "from the mail of Oct 8" line becomes a link on all three platforms.
- A tap opens the **record at that item**: the Record tab, scrolled to the mail or file, briefly highlighted — the way "Show" already jumps to a task.
- On the item, *Open in Mail* / *Open file* stays in its ⋯ menu.
- A task asked for by several mails shows "from the mail of Oct 8 · +2". The menu lists every source.
- Done tasks keep the link to the mail that showed them done.

**From a record item to what came from it**

Under each record item, one line of small chips:

> ☑ 2 tasks · 📅 1 date · ⚑ 1 deadline

- A tap on a chip shows those items in place (a small popover on the Mac, a sheet on iPhone/iPad) with *Show* to jump to them in Plan.
- An item with nothing linked shows nothing extra — quiet means "only information".
- Files attached to a mail count with their mail: their tasks are the mail's tasks.

**How it's computed:** a new `RecordLinks` in MatterCore builds, once per drawing, a map from Message-ID to the tasks, appointments and deadlines whose `sources` name it. No new relationship in the store, so nothing changes for iCloud or the other devices.

### 2. Read or kept — two looks

Every record item gets one of three states, worked out from what is already stored:

| State | What it is | Look |
|---|---|---|
| **Read** | A mail's body; a file added with **+ File**, scanned or dropped (it has a digest). The assistant can answer from it. | White card, as today, with its text. A small "Read" mark is unnecessary — the text is the mark. |
| **Kept, not read** | Files from **Files or a folder**; mail attachments. Stored, openable, never read, never sent. | Dashed outline, no text block, and a plain line: **"Kept only — Causabee hasn't read this."** |
| **Kept, can't be read** | Word files, invitations, other types Causabee can't read yet. | As "kept", saying **"Kept only — this kind of file can't be read yet."** |

- A kept file has a **Read it** action in its ⋯ menu. It runs the same reading as **+ File**, and the card turns into a read one. This is the only way something kept gets read, and it costs what a file costs.
- The record's menu gets a count for each: *Read · 41* and *Kept only · 12*.
- In the assistant's footer, "Sees: …" already names what it reads; it will say "and not the 12 kept-only files".

### 3. More text, and a way to browse

**Each mail card shows**

- Sender and date, as today, and the conversation's subject on top. A reply whose subject differs shows its own.
- The digest, no longer cut at 3 lines: up to 5, with *more* to show it whole.
- Below it, **the quoted words** that produced each linked task or date (they're stored already as `sourceQuote`), in quotation marks, next to the chip they belong to.
- On the Mac, where the mail's full text is kept locally, *Show the whole mail* expands it in place, without opening Mail.

**Browsing**

The single menu becomes a bar with three controls:

- **Kind:** Everything · Mail · Files · Scans · Links · Details
- **Show:** All · With tasks or dates · Information only · Kept only · Unread
- **Sort:** Newest · Oldest · By person · By kind

Grouping follows the sort: by month for Newest/Oldest, by person, or by kind. Conversations stay together in every sort. The current filter by person (from People) becomes the "By person" grouping plus a person filter chip, as today. ⌘F keeps searching everything shown.

On iPhone the bar is one row of three compact menus under the tabs; on iPad and Mac, the same three menus on the record's line.

### 4. Unread mail

- At each mail check, Causabee also asks the mailbox for the **read flag** of the matter's mails. It's a header-only, read-only request (`UID FETCH … (FLAGS)`), which the mailbox allows without changing anything. Causabee's own guard (only `PEEK` reads) stays as it is.
- A new field `Entry.isUnread` (Bool, optional) holds it. It syncs, so all devices show the same.
- An unread mail shows a **gold dot** before its sender and its subject in medium weight, as Mail does.
- The matter's line in the overview and the sidebar says "2 unread" beside "1 overdue".
- The state is as fresh as the last mail check. Reading the mail in Apple Mail clears the dot at the next check, not at once.
- Mail that came in by forwarding to yourself, or a scan, has no unread state.

## What changes where

| Part | Change | Size |
|---|---|---|
| MatterCore | `RecordLinks` (Message-ID → tasks/dates); `RecordItem.state` (read / kept / can't read); `Entry.isUnread` + flags fetch in the mail check | medium |
| Mac record | Card with subject, longer digest, quotes, link chips, kept look, the three-menu bar, highlight on jump | large |
| iPhone/iPad record | Same, and the task's source line becomes a link | large |
| Plan (all) | Source line → opens the record at the item; "+2" for more sources | small |
| Overview / sidebar | "n unread" | small |
| Assistant footer | Names what it doesn't read | small |
| Figma | Record card (read / kept), link chips, the bar, unread dot | medium |

No migration risk: one optional field is added; everything else is computed.

## Phasing

1. **Links both ways** — task/date → record item, record item → chips. The biggest daily gain; no model change.
2. **Read vs kept** — the two looks and *Read it*.
3. **Card and browsing** — subject, longer text, quotes, the three menus.
4. **Unread** — flags fetch, dot, counts.

Each phase is a demo on all three devices before the next.

## Open questions for you

1. **Mail attachments:** should they stay "kept only", or should Causabee read PDFs that come with a mail when it sorts the mail? Reading them costs more per mail and sends more (disguised) text to the AI.
2. **Unread in the overview:** only a count per matter, or also a filter "Matters with unread mail"?
3. **Sort by person:** by who wrote it, or by everyone named in it?
4. **Kept files and the assistant:** is "it doesn't read them" the right default, or should the assistant at least know their names?
