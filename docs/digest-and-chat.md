# Digest and chat: where Causabee is used

Written 6 November 2026, from the owner's words. A principle to design by, and a check of the app
as it is against it.

## What Causabee is for

Causabee takes the mental load. The owner puts things in and knows they are there, sorted, and
not forgotten — and has them when they are needed.

- **The owner brings everything in by hand**, so the owner already knows what came in. Causabee
  never announces back what the owner just gave it: no "new mail", no "look what I found".
- **Causabee is on the owner's side, not a coach.** No "you should do this, think of that". It
  says what is due, what is waiting, and what it remembers that the owner could not.
- **Short, precise sentences, on point, on time.** One line that says the fact, at the moment it
  matters — not when the thing arrived.

What makes it smart is what the owner cannot hold in their head:

1. **The typing it saves.** Deadlines, amounts, reference numbers, people and the right matter
   come out of the file by themselves.
2. **Memory across time and matters.** "Third reminder." "Paid in October." "Clashes with the
   physio on Tuesday." "Changes what the landlord wrote in March." Causabee speaks up only when it
   adds something the owner could not see at a glance.
3. **Time, not arrival.** A thing comes back when its day is near, when it is overdue, or when a
   fact may be outdated.

### When Causabee confirms

Once, when the owner adds something — and only if Causabee made something from it (a task, a date,
a fact): "Filed under Kita. Pay €120 by 20 Nov." with change and undo, right where it was added.
Filed with nothing made: no confirmation. After that it does not come up again until its time.

### Notifications

Off for now. Nothing arrives without the owner, so there is nothing to tell. The first ones worth
having are reminders by time ("Kita fee due tomorrow"), scheduled on the device when the date is
made — no background work needed.

## The principle

Causabee is used in two places: **a matter's Digest** and **the chat**. Everything else is there to
look things up.

1. **Bring it in.** Mail comes by itself; files, scans and screenshots through the chat's plus.
2. **Check what Causabee made of it — once, when adding.** The tasks, dates and facts it found,
   confirmed in one line where the thing was added: change or undo. Not again later.
3. **Add the odd thing.** A task, a note, a detail — in the chat, by its panel or in words.
4. **Day to day: the Digest and the chat.** What is next, what is new, what is good to know, and
   asking. The owner is fine without ever opening another tab.

The other tabs — Plan, Mail, Files, People, Notes — are the archive: the full list, every mail,
every file, every person. Opened when the owner wants the detail, never needed for the routine.

The overview is the same idea across all matters: the Digest of everything.

### Design rules that follow

- **Nothing routine needs another tab.** If a regular action only works in Plan, Mail, Files,
  People or Notes, it is in the wrong place — or it needs a way in from the Digest or the chat.
- **What Causabee made is checked where it was added.** One confirmation line at add time, with
  change and undo. The Digest does not repeat it as "new". (Replaces the "New" card of 6 November.)
- **The Digest is about time and memory, not arrival.** What is due, what is waiting on the owner,
  and what Causabee noticed across the matter's history. With nothing of that, it is calm.
- **The chat can do what the Digest can't show.** A change in words — "move the physio to Tuesday",
  "that one is done", "forget the insurer's letter" — ends in a card to tick, never in "go to Plan".
- **Jumps out are for looking, not for doing.** "Show", a source, a mail: they open the archive to
  read, and the owner comes back without having to finish anything there.
- **A tab is not a mode.** No action is hidden in one tab that the owner would expect on the Digest.

### What appears where — one job per place (7 November 2026)

Settled with the owner after days of back and forth. Each place has one job; the job alone decides
what is shown there. "The owner knows it already" holds only where the job is about what came in.

| Place | Its one job | What the owner did |
|---|---|---|
| **Latest updates** (overview) | A diary: the last thing that happened in each matter | Shown, like everything else |
| **New** on the Digest | What came to the owner and is not seen yet | Never |
| **Notifications** | Reminders for days that are set | Never |
| **The bee's proposals** | Only what a mail says: new task, done, a date | Never |
| **Plan** | Everything still to do, by day | Shown |

**Yellow says where it came from.** A Latest update that came to the owner (mail, file) and is not
seen yet carries the honey dot and a yellow symbol. What the owner made — a note, a task, a tick —
is grey. Yellow still means one thing: something waits for the owner.

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

## Open: the hand work of bringing things in

Written 6 November 2026. The concept stands; the cost is the intake. Today every mail needs the
"Causabee" label or folder, and every screenshot or file is shared or added by hand. The owner
says yes to each thing. That is a lot of hand work for a product meant to take load away.

Where the hand work could shrink, most leverage first — none decided:

1. **Say yes once per sender, not per mail.** When a mail from the school lands in Kita, Causabee
   offers: "Always take mail from the school?" After that, that sender's mail comes in by itself.
   Needs Causabee to look at the inbox's senders (headers only) — a deliberate widening of what it
   reads, opt-in per sender. On Gmail it could set the label filter itself.
2. **Never ask where it goes.** The share sheet and the chat file it into the right matter by
   themselves; the confirmation line names the matter, with a way to move it. Choosing a matter is
   for when Causabee is unsure.
3. **Many at once.** A batch of screenshots or a folder of PDFs in one go, sorted and confirmed in
   one summary line per matter.
4. **Threads follow by themselves** (already true for Gmail labels): once a thread is in, its
   replies are too.

The test for each: does the owner do less, and does the owner still know everything that is in?

## Sketch: never ask which matter

Written 6 November 2026, chosen by the owner as the first intake idea to work out.

### Today: five decisions for one screenshot

From another app's share sheet: (1) choose a matter or "Causabee decides", (2) Add, (3) open
Causabee, (4) "Sort in" on the scanned card, (5) untick what it found, choose where it goes, "Take
in". In the chat the same card asks (4) and (5). Each step is a yes the owner already gave by
sharing.

### The flow

1. **Share → Causabee.** The share sheet shows the picture and one button, **Add**. No list of
   matters. Done in one tap. (A small "Into…" under it for the rare case the owner wants to say.)
2. **Causabee sorts it in by itself** when it next runs — scan, read, file, make the tasks and
   dates. Sharing is the yes; there is no "Sort in" any more. In the chat of a matter, a file added
   there goes into that matter without asking.
3. **One line confirms it**, at the top of the chat or the overview, once:
   - made something: "Kita · Pay €120 by 20 Nov." — tap to see it, **Change** or **Undo**.
   - only filed: "Kita · filed." — fades after a moment.
   - several at once: one line per matter: "Kita · 3 screenshots · 2 tasks."
4. **Only when unsure, ask — with the answer ready.** "Kita or Steuer?" as two buttons with the
   likelier first, and "New matter". Never a list of all matters. Unsure means: no matter fits
   clearly, or two fit about the same.

### What decides the matter

The same reading as "Sort in" today, plus what Causabee already knows about each matter: its people
and senders, reference numbers, amounts, places, recent mail. A reference number or a known sender
is enough on its own; topic alone is not.

### Change and undo

- **Change** opens the item's own sheet (as from the Digest): words, day, whose, and **Move to…**,
  which takes the file and everything made from it to another matter.
- **Undo** takes it all back out. The file stays in Files as unsorted for a day, then goes.

### Decided: bringing it in is the yes

Decided by the owner, 6 November 2026: putting a mail under the label, sharing a screenshot or a
PDF, adding a file in the chat — that is the yes to sort it in. No "Sort in", no "Take in", no
"Read or only import". Privacy that costs five steps is not a product. The promise stays in what
is sent, not in asking: with Pro, pseudonymised; without, read on the device, nothing leaves it.

### Still to settle
- **When it runs.** The share extension cannot do the work; it waits until Causabee is opened (or
  a background task, later). The line is there when the owner next looks — which is when they want
  to know.
- **The Mac.** A file dropped on the window or the dock: the same, no "Sort in".

### Built, 6 November 2026

- Files, scans, photos and screenshots — from the chat's plus, the share sheet, or dropped on the
  Mac — sort themselves in. No "Sort in", no "Take in". The plus asks "read or only import" only
  for more than five files at once.
- Sure of the matter (brought in from a matter, or Pro's model names an open one at 0.6 or more —
  the device's model never decides the matter alone, the owner does not trust it with that):
  filed, with what the matter already has left out. Not sure: "Which matter?" with the likelier one
  as the button and "Other".
- One line says it: "Care for Mum · Answer “hkk Krankenkasse”", what else it brought, the file, and
  Change (open, Move to …) and Undo. Kept in the thread, the same on every device.
- The share sheet: one Add; the matters folded under "Into a matter …".

- Mail: labelled is the yes. Read (with Pro by itself, without it after "Sort in"), it goes straight
  into its matters — no "N mails read · Take in" card. The receipt says where each went, with Move;
  a mail with no matter found is among the mail without a matter, not dropped.

- Notifications off: no "1 new mail", no matter news. Nothing comes in that the owner did not
  bring, so there is nothing to tell. Causabee no longer asks to send notifications.

Not yet: mail without Pro still waits for "Sort in" — the device's model is not trusted to start
on its own (the owner, 6 November 2026); the
Digest's "New" card is still there, though the line at add time now does its job.

## Taking the monitoring too: a day for everything, answers that come back, the week in a sentence

Written 6 November 2026, from research the owner asked for and liked:

- Mental load is the planning, anticipating and monitoring — not the doing. An app that takes the
  doing but leaves the monitoring takes "a sliver" of it (Ruppanner, in The Spinoff, Sept 2026).
- An unfinished goal stops intruding once there is a plan for it — a when — even before it is done
  (Masicampo and Baumeister 2011, "Consider it done!").
- A trusted system is one with no hidden gaps: GTD's weekly review closes open loops and checks
  what one waits for from others.
- Help nobody asked for backfires, even when right; proactivity is selective, on time, and shows
  what it rests on.

What Causabee does with it (built 6 November 2026, no iCloud schema change):

1. **Every task gets a day.** A task with no day shows "When? This week · Next week · Later" — on
   the confirmation line where it came in, and under "No day yet" on the Digest. This week is
   Friday (today at the weekend), next week the Friday after, later four weeks on: a day each, so
   even "later" is a plan.
2. **Waiting-for comes back.** Someone else's task comes back on its day, or a week after it came
   in: "No answer yet" on the Digest, with "Wait a week" or the tick. With Pro, a reply that shows
   it done ticks it off by itself (the extraction prompt's `done`).
3. **The week in a sentence**, over the overview's week: "This week: 3 things · waiting on 2 ·
   nothing slipping" — what is overdue or unanswered said in orange. **Taken out again (7 November):**
   too short to say anything and too cryptic to act on; the week's days under it already show the
   week, and each matter's Digest says what has no answer, by name.

4. **Reminders the day before** (iPhone): at nine the day before a task's day or a deadline —
   "Kita · Tomorrow: pay the fee". Planned on the phone whenever the matters change, so it comes
   with Causabee closed; nothing goes to Reminders. Someone else's task is not told — it comes
   back as "No answer yet". The only notifications Causabee sends.
