# The record: everything linked, read or kept, browsable

Concept and solution design · 19 October 2026 · branch `record-concept` · decisions of 19 October included

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

- **Decided:** mail attachments stay *kept only* — Causabee doesn't read them by itself.
- **Reading is one tap, on the card itself:** every kept card has a visible **Read** button on its right, not hidden in a menu. It runs the same reading as **+ File** (≈ 4 cents, disguised), and the card turns into a read one.
- **Several at once:** a mail with attachments has *Read all n attachments* on its card; the record's *Show: Kept only* view has *Select* to read several at once, with the total cost shown before anything is sent.
- The record's menu gets a count for each: *Read · 41* and *Kept only · 12*.
- **Decided:** the assistant knows the **names** of kept-only files — "Pflegevertrag_Entwurf.docx, kept, not read" — never what's in them. It can say "there is a contract draft, but I haven't read it; tap Read on it" instead of acting as if it didn't exist. The footer says "Sees: … · knows the names of 12 kept-only files".

### 3. More text, and a way to browse

**Each mail card shows**

- Sender and date, as today, and the conversation's subject on top. A reply whose subject differs shows its own.
- The digest, no longer cut at 3 lines: up to 5, with *more* to show it whole.
- Below it, **the quoted words** that produced each linked task or date (they're stored already as `sourceQuote`), in quotation marks, next to the chip they belong to.
- *Show the whole mail* expands its full text in place, without opening Mail — on every device (see *One app on every device*: the kept text has to be on all of them first).

**Browsing**

The single menu becomes a bar with three controls:

- **Kind:** Everything · Mail · Files · Scans · Links · Details
- **Show:** All · With tasks or dates · Information only · Kept only · Unread
- **Sort:** Newest · Oldest · By person · By kind

Grouping follows the sort: by month for Newest/Oldest, by person, or by kind. Conversations stay together in every sort. ⌘F keeps searching everything shown.

**Decided: "By person" means everyone named in it**, not only who wrote it. A mail stands under the writer, the recipients, and every person the sorting found in it — so a mail from the care service that names Mum stands under Mum too. Where a mail names several people, it appears under each, marked "also under …". The data is there: the record of sorted mails keeps the people found in each mail; mail sorted before that record existed falls back to writer and recipients. The current filter by one person (from People) becomes a filter chip on this view.

The bar is the same three menus on every device, in the same order, on the record's line.

### 4. Unread mail

- At each mail check, Causabee also asks the mailbox for the **read flag** of the matter's mails. It's a header-only, read-only request (`UID FETCH … (FLAGS)`), which the mailbox allows without changing anything. Causabee's own guard (only `PEEK` reads) stays as it is.
- A new field `Entry.isUnread` (Bool, optional) holds it. It syncs, so all devices show the same.
- An unread mail shows a **gold dot** before its sender and its subject in medium weight, as Mail does.
- **Decided: a filter, no count.** The overview gets *Matters with unread mail* as a filter; the record gets *Show: Unread*. The matter's line itself stays as it is.
- The state is as fresh as the last mail check. Reading the mail in Apple Mail clears the dot at the next check, not at once.
- Mail that came in by forwarding to yourself, or a scan, has no unread state.

## What changes where

| Part | Change | Size |
|---|---|---|
| MatterCore | `RecordLinks` (Message-ID → tasks/dates); `RecordItem.state` (read / kept / can't read); `Entry.isUnread` + flags fetch in the mail check | medium |
| Record (shared) | Card with subject, longer digest, quotes, link chips, kept look, the three-menu bar, highlight on jump — one view for Mac, iPhone and iPad | large |
| iPhone/iPad record | One shared record for all three, replacing both | — |
| Plan (all) | Source line → opens the record at the item; "+2" for more sources | small |
| Overview / sidebar | Filter "Matters with unread mail" | small |
| Assistant | Knows the names of kept-only files; footer says so | small |
| Figma | Record card (read / kept), link chips, the bar, unread dot | medium |

For the record itself: one optional field is added (`Entry.isUnread`); everything else is computed. Phase 0 adds the kept texts to the store and moves settings into the profile.

## Phasing

0. **Data the same everywhere** — D1 to D8. First, because the record's *Show the whole mail*, reading files and opening sources all depend on it.
1. **Links both ways**, built as one shared record — task/date → record item, record item → chips.
2. **Read vs kept** — the two looks, *Read* on the card, reading several at once, the assistant knowing names.
3. **Card and browsing** — subject, longer text, quotes, the three menus, *By person* by everyone named.
4. **Unread** — flags fetch, dot, the filters.
5. **The remaining feature differences** — the table above, area by area, each screen rewritten once.

Each phase is a demo on all three devices before the next. Phases 0 and 5 are the largest; 1–4 are about a phase each.

**Phase 0** shipped in Beta 73 (TestFlight 73), 19 October.

**Phase 1 status (20 October, branch `phase1-links`):** built. `RecordLinks` (MatterCore) files every task, appointment and deadline under the Message-ID and pointer of each source it names — a task a mail showed done counts for that mail too — and finds the record item a source points at. The conversation card is now one shared view for all three devices (`RecordViews.swift`: `ThreadCard`, `ThreadMailRow`, `ThreadRails`, `MailWay`), replacing the Mac's and the iPhone's two copies; only sizes and the menus' look differ by screen. `SourceJump` puts the "from the mail of …" line inside the task's own line, as a link: a tap opens the record at that mail or file and marks it; several sources say "· +2" and a tap asks which; a source not in the record opens in Mail where it can, or stays words. `MadeChips` under each mail and each file of its own (a file that came with a mail counts with its mail) show "1 task · 1 date · 1 deadline"; a tap lists them (a popover on the Mac, a sheet on iPhone and iPad), each with *Show*. Open in Mail stays in each mail's ⋯. File cards themselves are still drawn per platform — they get their one shared look in phase 2, when *read* and *kept* change them anyway.

**Phase 2 status (20 October, same branch):** built. `Document.reading` says *read* (it has a digest or was read), *kept*, or *kept, can't be read yet* (not a PDF or a picture); `Matter.keptFiles` lists the kept ones. One shared `FileFace` draws every file on all three devices — the Mac's Finder icons gave way to the same signs as the iPhone's. Read: its text, and "read Oct 3". Kept: a dashed card with no ground in the record, "Kept only — Causabee hasn't read this." and a visible **Read** (on the right on the Mac, under the words on the narrow iPhone), which brings the file into the assistant as "Scan" did — read on the device, nothing sent until *Sort in*. A mail with two or more kept files has *Read all n attachments · ≈ n×4 cents*. The record's menu has *Kept only · n*, with *Choose …* to read several at once, the cost shown before. The assistant's facts list the kept files by name only — "a kind of file Causabee cannot read yet" where so — and its footer says it knows the names of n kept-only files. Not yet: a *Read · n* count in the menu; it comes with phase 3's menus.

**Phase 3 status (20 October, same branch):** built. `RecordBrowse` (MatterCore) picks and groups the record for all three devices: **Kind** (Everything · Mail · Files · Scans · Links · Details), **Show** (All · With tasks or dates · Information only · Kept only, each with its count), **Sort** (Newest · Oldest · By person · By kind). One shared `RecordBar` draws the three menus on the record's line, the same order everywhere; a person chosen in People is a chip beside them and now means *wrote it or is named in it*. By person, a thing stands under everyone it names — the writer, who it went to, and every person of the matter whose name is in its subject, digest or kept words (`RecordBrowse.people`, worked out once per mail, `NamedPeople`) — marked "also under …"; mail naming nobody stands under *Nobody named*. Show *Kept only* opens the kept files to read (with *Choose*); Files and Links at All · Newest keep their own lists (hidden files, adding a link). The mail card: a reply whose subject changed says its own; the digest runs to five lines, with *more*; under the chips, the words each task, date or deadline was read out of, in quotation marks; *Show the whole mail* opens its kept words in place, on every device — the demo's mails have words kept too. *Read · n* as its own count was left out: *Information only* and *Kept only* say it better. *Unread* waits for phase 4.

**Phase 4 status (20 October, same branch):** built. At every mail check — on start, coming to the front, every ten minutes, by hand, on each device — `UnreadMail.refresh` asks the mailbox, folder by folder, `UID SEARCH UNSEEN`: a search, on the read-only list, that changes no flag (no `FETCH FLAGS` was needed). The answer goes on each mail of the last year as `Entry.isUnread` (synced; nil for scans, files and mail not asked about). An unread mail has a gold dot before its sender, the sender in semibold and its digest in full black. The record's *Show* has *Unread*. The overview has *Matters with unread mail*, folded on one line, no count; open, the matters with the day of their newest unread mail, each opening at that mail. Needs the CloudKit schema deployed (one new field on Entry); Development is done.

**Unread follows the inbox (decided 20 October):** Causabee never marks a mail read — not in the mailbox, not on its own. The dot goes when the mail is read in Mail or any mail app, at the next check; and opening a matter's record asks the mailbox about that matter's mails at once (read-only, at most once a minute per matter), so the dots are as the inbox has them the moment they are looked at.

## One app on every device

**The rule (decided 19 October):** Causabee is one app. The Mac, the iPhone and the iPad have the same features, the same actions under the same words, and the same data. Only the layout adapts to the screen, and only input that a device physically lacks may differ (a camera, a trackpad drag). Everything below applies to the whole product, and the new record is built this way from its first line.

A full check of the code (19 October) found these differences. Data first, because it changes what you see and what the assistant knows.

### Data that differs by device

| # | What | Today | Fix |
|---|---|---|---|
| D1 | **Kept texts** — the words of every mail read, every scanned PDF and screenshot | In a folder beside each device's own store. The Mac keeps the text of every mail it sorts; the iPhone keeps none. The assistant on one device can't read what the other one scanned. | Into the synced store, compressed and end-to-end encrypted (CloudKit's encrypted fields, as the store already uses for answers). Every device saves them when it takes something in. Needed for *Show the whole mail* everywhere. **This changes a promise:** the app and the privacy page say full mail texts stay on the device; they would then be in your private iCloud, encrypted end to end. Your call — see question below. |
| D2 | **File and screenshot cards in the assistant** | Mac: kept in the thread, synced. iPhone/iPad: only in memory — gone after a restart, never on the Mac. | Kept in the thread on every device, the same card. |
| D3 | **Files added by hand** | Copied into a local folder on the device that added them; the other device sees them only through the iCloud Drive matter folder, else "only there". | The matter's iCloud Drive folder is the file's home on every device; the local copy is only a cache. |
| D4 | **Mail account with Sign in with Google** | Works only on the Mac. The iPhone can't check that mailbox, open its attachments or search its links. | Sign in with Google on iPhone and iPad too. |
| D5 | **Which mail answers which** (conversations) | Worked out only by the Mac. | By whichever device opens the record. |
| D6 | **Settings** — Auto on/off, what Auto wrote and spent, *Fewer, real tasks*, *The bee is glad*, calendar and list for new entries | Each device has its own. | In the synced profile, like the model choice already is. Calendars by name, so they match across devices. |
| D7 | **How often mail is checked** | Mac: at start, every 10 minutes, after waking. iPhone: when the overview opens, at most every 2 minutes, and by pulling down. | The same everywhere: at start, when it comes to the front, every 10 minutes while open, and on demand (button and pull-down). |
| D8 | **Owner's names** | Editable on the Mac only. | Editable in Settings everywhere. |

**Phase 0 status (19 October, branch `phase0-data`):** D1, D2, D3, D5, D6, D7 and D8 are built. D4 turned out not to be a difference today: Sign in with Google isn't switched on in any build yet (it has no Google client), so no device can use such an account; when it is switched on, it has to come to all devices at once.

Already the same everywhere, no change needed: what was sorted, what was left out, the name list for the disguise.

### Features and actions that differ

| Area | One side only today | Becomes |
|---|---|---|
| Task / date / info source | Mac opens it; iPhone shows plain text | Opens the record item everywhere (part 1 above) |
| Adding a task | Mac: direct editor (⇧⌘T); iPhone: only through the assistant once tasks exist | Direct editor everywhere, plus the assistant |
| Record line | Mac: + File, Show in Finder, counts; + Link / + Detail / + Contact in headers | The same buttons everywhere; *Show folder* opens Finder or Files |
| Reading a file you added | Mac can read and name your own files; iPhone only mail files | Read and *Name from content* for every file, everywhere |
| Opening a scanned or dropped item | Mac opens the file; iPhone only Mail | Opens the file everywhere |
| Find in a matter | Mac searches all mail; iPhone about the newest 60 | All, everywhere |
| Assistant answer | Mac: Try again, "what was sent", "read X as Y" | All of them everywhere |
| Assistant plus | iPhone offers adding to a matter from the overview; Mac's overview only reads | The same plus, with the matter picker, everywhere |
| Earlier turns | Mac shows 30, iPhone 8 | One number everywhere (20) |
| Reading mode | Mac hides suggestion cards, iPhone doesn't | The same everywhere |
| Rewrite next step and summary | iPhone: pull down the page | Pull down, and *Write again* in the ⋯ menu everywhere (⌘R on the Mac) |
| Screenshot by paste or drop | Mac only | Mac and iPad (keyboard and drag), iPhone by paste |
| Scan with the camera | iPhone/iPad only | Mac too, through *Scan from iPhone* (Continuity Camera) |
| Overview | Quiet and closed matters in different places; Rename/Merge missing on Mac cards; "… and n more overdue" not tappable on iPhone | One arrangement, one menu, all tappable |
| Matter header | Mac shows "n mails · since …", tasks "n open · m done" | The same everywhere |
| Wording | "Edit …" vs "Edit", "Waits for nothing any more" vs "Stop waiting", "Rename …" vs "Rename", and more | One set of labels |
| Wrong text | iPhone Settings says screenshots and files are sorted in on the Mac — they're sorted on the iPhone too | Removed |

### How it goes away for good

- **One view per feature.** Today most screens are written twice, once in `Sources/Causabee` and once in `Sources/CausabeePhone`, which is how the differences crept in. Each screen we touch is rewritten once, compiled into both apps, with layout chosen by the space it has — not by the platform. The new record is the first.
- **One label list** in shared code for every menu and button.
- **A parity check before every release:** a short list of the features above, ticked on Mac and iPhone.

## Decisions (19 October)

1. Mail attachments stay *kept only*; reading one is a single visible **Read** on its card, and several can be read at once.
2. Unread is a **filter**, not a count: *Matters with unread mail* in the overview, *Unread* in the record.
3. *By person* groups by **everyone named in the mail**.
4. The assistant knows the **names** of kept-only files, not their contents.
5. **One app on every device** — see below. This applies to the whole product, not only the record.

## Still open

1. **Kept texts in iCloud (D1).** For the same data on every device, the full texts of mails and scans have to sync — end-to-end encrypted, in your private iCloud. Today the app promises they stay on the device. Is the new promise "they stay in your own iCloud, end-to-end encrypted, and never reach anyone else" acceptable? Without it, *Show the whole mail* and the assistant's knowledge stay per device.
2. **Sign in with Google on iPhone (D4)** needs the iPhone app registered with Google as a client of its own. Whether Google wants to review the mail access again for it is not known yet; if so, that time is outside our hands.

**Phase 5 status (20 October, branch `phase5`):** built in three parts. (1) The matter page — header counts, the six ways to add, Write Next Step and Summary Again (⌘R), find over all mail, files opening as files, Name From Content for every PDF; then one place to add: the plus, the same list in three parts on every device, Task and Note opening their editors, and the ⋯ only about the matter. (2) The assistant — Try again, what was sent and "read X as Y" on the iPhone and the iPad, reading mode there too, 20 turns at a time everywhere, paste and drop on the iPhone and the iPad, Import from iPhone (Continuity Camera) on the Mac. (3) The overview and the words — the Mac's overview folds the quiet and the closed matters as the iPhone's does, every matter's card, row and sidebar entry has the same menu (`MatterMenuItems`, shared), one list of words (`Say`), and `docs/parity-checklist.md`, which the release script points to.

## Noted for later

- **Demo: "what was sent" is an empty box.** Tapping an answer's price opens who answered and what was sent; the demo's made-up answers send nothing, so the box under the model's name is empty. Say "Nothing was sent for this answer." instead, on the Mac and the iPhone/iPad (`AssistantView.swift` and `AssistantSheet.swift`, where `answer.sent` is shown). Cosmetic, demo only — the owner said to skip it for now and not forget it (20 October).
