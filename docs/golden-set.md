# Making the golden set

The golden set is 50 emails you have read and written down the truth about. Everything the
spike claims later — how much the bulk filter catches, whether stand-ins beat placeholders,
how good to-do extraction is — is measured against this file and nothing else. It is the one
part of Phase 0 a machine cannot do.

Budget about an hour and a half. You can do it in two sittings; `check` tells you where you
stopped.

---

## Part 1 — Export the mail

**1. Make a folder for it.**

```sh
mkdir -p Samples/private/mail
```

`Samples/private/` is in `.gitignore`. Real mail never reaches a commit.

**2. Open Mail and open that folder in Finder next to it.**

**3. Select messages and drag them into the Finder window.**

Mail writes one `.eml` file per message, named after the subject. Cmd-click for a scattered
selection, Shift-click for a run of them. Drag in batches of twenty or so rather than all at
once.

**4. Export about 150 messages, and do not tidy them up first.**

This is the part that is easy to get wrong. If you only export the interesting mail, question 1
of the plan — how much the rules-only filter catches — has nothing to measure, and the answer
comes out as 100% of nothing. The pile needs to look like your actual inbox:

| What | Roughly how many | Why it has to be in there |
| --- | --- | --- |
| The Hausverwaltung thread, all of it | as many as it is | The matter the whole app exists for |
| Two or three other real threads | 20–30 | So clustering has more than one matter to find |
| Newsletters and marketing | 30–40 | What the bulk filter is for |
| Notifications, receipts, confirmations | 30–40 | Where the bulk filter goes wrong |
| Ordinary personal mail | 20–30 | Mail with a to-do in it and no matter behind it |
| The awkward ones | a handful | Bank notices, booking confirmations, anything you had to think about |

Three months is the right window. Mail from last year has no live to-dos in it.

**5. Do not rename the files.**

Mail handles duplicate subjects by numbering them. The file name is how a row in the
spreadsheet and a message find each other.

> If you end up with `.emlx` files rather than `.eml` — which happens if you copy out of
> `~/Library/Mail` instead of dragging — that works too. The parser unwraps them.

---

## Part 2 — Make the spreadsheet

```sh
swift run matter-spike labels Samples/private/mail --out labels.csv
```

That writes one row per message with the facts already filled in — file name, Message-ID, date,
sender, subject — and the six judgement columns left empty.

They are empty on purpose. A golden set filled in with the pipeline's own answers and then
corrected measures nothing: agreeing is the path of least effort, and the numbers come out
flattering. Label from the mail, never from what the tool said about it. Don't run
`matter-spike run` on this folder until the labelling is finished.

The command refuses to overwrite an existing `labels.csv`. It is the one file here that cannot
be regenerated.

---

## Part 3 — Label

Open `labels.csv` in Numbers. To read a message while you work on it, double-click its `.eml`
in Finder — it opens in a Mail window.

When you are done, **File → Export To → CSV**, and replace `labels.csv`. Numbers will not save
a `.csv` in place; if you forget, you will have a `.numbers` file and the tools will not see
your work. A plain text editor is also fine if you prefer.

### The six columns

| Column | What goes in it | Example |
| --- | --- | --- |
| `is_bulk` | `yes` or `no` | `yes` |
| `matter` | a short lowercase name you make up, or empty | `hausverwaltung` |
| `parties` | `Name (role)`, several separated by `\|` | `Annegret Berger (Hausverwaltung) \| Thermotec Nowak GmbH (Anbieter)` |
| `todos` | `text (me\|other) -> YYYY-MM-DD`, several separated by `\|` | `Begehung bestätigen (me) -> 2025-10-09 \| Angebote vergleichen (me)` |
| `deadlines` | `what -> YYYY-MM-DD` | `Sonderumlage überweisen -> 2025-11-30` |
| `notes` | anything you want to say | `war schwer zu entscheiden` |

Leave a cell empty when the answer is nothing. An empty `is_bulk` means *not labelled yet*, not
`no` — that is how `check` knows where you stopped.

### How to decide each one

**`is_bulk`** — Judge how it was *sent*, not whether it is useful.

> Bulk means: the same message went to a lot of people, and nobody is waiting for you to reply.

Newsletters, marketing, list mail, "your build failed" — bulk. A bank notice addressed to you
about your account is personal and transactional, so `no`, even though a machine sent it and
you will never reply. That distinction is exactly what question 1 is about, so it is worth
being careful on these.

**`matter`** — A matter is something that runs over a stretch of time, has people in it, and
has steps that are not finished. A heating replacement is a matter. A dinner invitation is not.

Use the same spelling every single time — `hausverwaltung`, not `Hausverwaltung` once and
`hv` later. Leave it empty when a mail belongs to no matter; most will. If you cannot decide,
leave it empty and write why in `notes`.

**`parties`** — Only people and companies that are *part of* the matter. Not everyone whose
name appears. The role is your own words: `Hausverwaltung`, `Anbieter`, `Nachbar`, `Kundin`.
Leave `parties` empty when `matter` is empty.

**`todos`** — Something somebody has to *do*, taken from what the mail says, written short in
your own words. `(me)` if it is yours, `(other)` if it is someone else's, and leave the marker
off if the mail does not make it clear. Add `-> 2025-10-09` only when the mail gives a date.

Only what is actually in the message. If a mail implies you should probably chase something,
that is not a to-do — it is exactly the kind of invention we will be measuring the model for.

**`deadlines`** — A date by which something has to happen, whether or not anyone said who does
it. "Angebot gebunden bis 31.10." is a deadline with no to-do attached.

An invitation is not a matter, but the date to reply by is a deadline: "Bitte gebt bis 14.06.
Bescheid" goes in `deadlines` even though `matter` stays empty. The date of the event itself is
not a deadline unless something has to be done by then.

**`notes`** — The most valuable column in the file, and the easiest to skip. Write a line every
time you hesitate. When the report says the model got something wrong, these notes are how you
will know whether the model was wrong or the label was.

---

## Part 4 — Check it

After every sitting:

```sh
swift run matter-spike check Samples/private/mail --labels labels.csv
```

It tells you how far you have got, which files are still blank, which files in the folder have
no row and which rows point at no file, and which cells it cannot read — a `vielleicht` in
`is_bulk`, a `30.09.2025` where a `2025-09-30` belongs. It compares nothing against the
pipeline. That is step 8 of the plan, and steps 5 to 7 come first.

Fifty labelled rows out of a hundred and fifty exported is the target. Labelling the obvious
bulk goes quickly; spend the time on the matter thread and the awkward ones.

---

## A thread set, for the manual edition

The set above is a slice of a whole inbox, noise and all, because it was made to measure the
automatic edition: does the bulk filter catch the newsletters, does a matter emerge from the mix.
The manual edition asks something narrower. Only mail you put the label on is sent, and replies
follow their thread, so the question is: **of the mail you would label, does it get the to-dos
right?** That needs a set made of nothing else.

**1. Export whole threads, including your own replies.** Pick three to five matters and drag each
conversation out of Mail whole, from the first mail to the last. Turn on *View → Organize by
Conversation* first: that shows your sent replies inside the thread, and dragging the
conversation takes them along. Your own replies matter more than anything else in this set —
"Ich schicke Ihnen die Liste bis Freitag" is a to-do for you, and it is only in your sent mail.

```sh
mkdir -p Samples/private/threads
```

No newsletters, no notifications, nothing you would not label. Sixty to a hundred mails is
plenty, and every one of them gets labelled.

**2. Make the spreadsheet with `--threads`.**

```sh
swift run matter-spike labels Samples/private/threads --threads --out labels-threads.csv
```

The rows come out thread by thread, oldest first, so you label a thread from top to bottom the
way you read it.

**3. Label.** The columns are the ones above, with one exchange:

| Column | What goes in it |
| --- | --- |
| `tapped` | `yes` on the mail you would put the Causabee label on — usually the first of a thread. `no` on the replies, which are meant to follow by themselves. |
| `matter` | as before, the same spelling on every mail of the thread |
| `todos` | **the main part.** `(me)` for your own, `(we)` for what you do together with others, `(other)` for someone else's that you are waiting for. A date only when the mail gives one |
| `parties` | as before: `Name (role) \| Name (role)` |
| `deadlines` | only when there is one. Empty is the normal case, not a gap |
| `notes` | whenever you hesitate |

**Whose is it?** Three kinds of to-do, and one kind that is not a to-do at all:

| Mark | Means | Example |
| --- | --- | --- |
| `(me)` | you have to do it | Tagesordnung prüfen (me) |
| `(we)` | you do it together with others, as one of a group | Brenner zur Einberufung auffordern (we) |
| `(other)` | someone else has to do it, **and you are waiting for it** | Einladung zur Versammlung verschicken (other) |
| — | someone else's task that you are *not* waiting for | leave it out |

Two things are new in a thread and worth a line in `notes` when you see them:

- **A to-do that a later mail settles.** "Bitte schicken Sie die Eigentümerliste" in one mail,
  the list attached two mails later. Label the to-do where it is asked; write in `notes` of the
  later mail that it settles it. Tracking that is not built yet, and these notes are what it
  will be measured by.
- **A reply that is really about something else.** A thread that changes subject halfway is where
  following by thread goes wrong. `tapped` stays `no`, the `matter` is whatever it is now about,
  and `notes` says so.

**4. Check it.**

```sh
swift run matter-spike check Samples/private/threads --labels labels-threads.csv
```

It counts against every row, since every row is meant to be labelled, and shows how many you
tapped and how many follow by thread.

---

## Four rules

1. **Label from the mail, not from the tool.** Never run the pipeline first and correct it.
2. **Same spelling for a matter, every time.**
3. **When unsure, write the reason in `notes`** rather than picking the tidier answer.
4. **Do not go back and change labels to match the tool later.** If a label turns out to be
   wrong, change it because it was wrong, and say so in `notes`.

## Where it all lives

`Samples/private/`, every `labels*.csv`, every `decisions*.jsonl` and `review*.html`, and
`mapping.json` are all in `.gitignore`.
They are made from real mail and stay on this machine.
