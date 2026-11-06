# Digest and chat: where Causabee is used

Written 6 November 2026, from the owner's words. A principle to design by, and a check of the app
as it is against it.

## The principle

Causabee is used in two places: **a matter's Digest** and **the chat**. Everything else is there to
look things up.

1. **Bring it in.** Mail comes by itself; files, scans and screenshots through the chat's plus.
2. **Check what Causabee made of it.** The tasks, dates and facts it found, on the Digest: keep,
   correct, or put away.
3. **Add the odd thing.** A task, a note, a detail — in the chat, by its panel or in words.
4. **Day to day: the Digest and the chat.** What is next, what is new, what is good to know, and
   asking. The owner is fine without ever opening another tab.

The other tabs — Plan, Mail, Files, People, Notes — are the archive: the full list, every mail,
every file, every person. Opened when the owner wants the detail, never needed for the routine.

The overview is the same idea across all matters: the Digest of everything.

### Design rules that follow

- **Nothing routine needs another tab.** If a regular action only works in Plan, Mail, Files,
  People or Notes, it is in the wrong place — or it needs a way in from the Digest or the chat.
- **What Causabee made is shown where it is checked.** New tasks, dates and facts appear on the
  Digest as new until the owner has seen them, with keep, correct and put away right there.
- **The chat can do what the Digest can't show.** A change in words — "move the physio to Tuesday",
  "that one is done", "forget the insurer's letter" — ends in a card to tick, never in "go to Plan".
- **Jumps out are for looking, not for doing.** "Show", a source, a mail: they open the archive to
  read, and the owner comes back without having to finish anything there.
- **A tab is not a mode.** No action is hidden in one tab that the owner would expect on the Digest.

## Pressure test: the app on 6 November 2026

What the code does today, against the four steps. ✅ holds · ⚠️ partly · ❌ breaks it.

### 1 · Bring it in

- ✅ Files, scans, photos: the chat's panel, on every device.
- ⚠️ New mail is sorted in on the **overview** (iPhone) or the Mac's sidebar — "3 mails sorted into
  3 matters · Move" — never on the matter's Digest. Fine as the Digest of everything, but a mail put
  in the wrong matter can only be moved there.

### 2 · Check what Causabee made

- ❌ **New tasks are not shown as new.** No task carries a "new" mark. They show up only indirectly:
  the adviser's news (Pro), the chips under a mail once its thread is unfolded, the overview's
  receipt. The "NEW" on a thread follows the mailbox's unread state, not what the owner has seen.
- ❌ **Tasks without a day never appear on the Digest** — only as a count in "N tasks open". The
  days-ahead card shows dated items only, and only the first item of each day.
- ❌ **Correcting a task needs Plan.** On the Digest a task can only be ticked. Its words, whose it
  is, its day, "only after", hide and delete are in Plan's row menu. "Show" on the next step jumps
  there.
- ✅ The adviser's proposals ("N questions from Causabee") are on the Digest, each with one button.

### 3 · Add the odd thing

- ✅ Task, note, link, detail, contact: the chat's panel, on every device.
- ⚠️ Changing what exists by words: the chat proposes cards for done, new, words, owner, day and
  waits-for — but none to hide or delete, to undo "done", or to change a task's note.

### 4 · Day to day on the Digest and in the chat

- ✅ Next step with Done / Write message, the summary and brief, Good to know, the days ahead, the
  mail journal with whole mails and files openable from it.
- ✅ The chat answers with sources, drafts mail, and its sources open the exact mail or task.
- ⚠️ **Without Pro the Digest is thin.** No news, no proposals, no Good to know, a summary only if
  one was written before; the chat only adds. The routine then leans on Plan.
- ⚠️ Mac and iPhone differ in order: the Mac shows the days ahead before the summary, and "who has
  the ball" only on the Mac and the iPad's column.
- ✅ Rare things stay in the ⋯ menu (close a matter, export) — rare, so that is fine.

## What it asks of the next designs, most important first

1. **"New" on the Digest.** Tasks, dates and facts from mail not yet seen, at the top, each with
   keep (it stays), correct (inline), put away — and one "Seen" for all. Without Pro: what the owner
   added on other devices and what files brought.
2. **A task's own sheet from the Digest.** Tapping a task anywhere on the Digest opens its editor in
   place — words, whose, day, only after, hide, delete — instead of jumping to Plan.
3. **Undated tasks on the Digest.** A short "No day yet" line with the first two or three and "Set
   day", so nothing open is invisible.
4. **The chat completes the set.** Cards to hide or delete an item, undo "done", and change a note,
   so anything said in words ends in a card.
5. **Decide what the free Digest is.** Either the rule-based Digest is enough without Pro, or the
   principle is Pro's — and the free app says so.
6. **One order on every device** for the Digest's cards.
