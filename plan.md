# Matterbee: Build Plan

Matterbee is a personal, privacy-first app for iPhone and Mac that turns scattered emails, documents and screenshots into organized **matters**: parties, timeline, to-dos, deadlines, decisions.

Full product spec: *Matterbee — Plain-Language Spec* (Claude Doc). This file is the working plan for Claude Code.

---

## Ground rules (apply to every phase)

- **Store facts, not copies.** Keep extracted facts plus a pointer to the original (message ID, file path). Never mirror a mailbox. A file the user attaches is kept by reference when it has a home of its own — a PDF in Files, an asset in Photos — and copied in only when it has none, such as a screenshot shared from another app. The app says which of the two it did.
- **Read it on the device, and say what you could not read.** A PDF's text layer, a screenshot's OCR, a photo of a letter: all of it is extracted locally before any of it is disguised and sent. A page that is a scan with no text layer is stored as an image and reported as unread, never quietly skipped.
- **A screenshot carries more than you meant.** Notification banners, other conversations, account numbers. Anything found outside what the user is plainly pointing at is named and excluded before sending, not silently included.
- **A chat screenshot is structured, not a blob of text.** Group name, participant list, who spoke, the minute they spoke, date separators, delivery ticks, attached images. Bubble side says which messages are the user's own, so their own promises come out of it too. Read it as a thread with speakers, never as one undifferentiated paragraph.
- **Nothing identifiable reaches the API.** All text sent to Claude is pseudonymized on the device first. The mapping never leaves the device.
- **Read-only on mail.** The app never sends, deletes or moves emails.
- **The user confirms.** Every AI decision is a suggestion with a reason. Nothing is written to Reminders or Calendar without confirmation.
- **Every decision is explainable.** Each decision records which layer made it (rule, on-device, Claude), a confidence, and a one-line reason.
- **Words in, cards out.** You can say or type anything to Matterbee — a correction, an instruction, a decision, a whole errand — and what comes back is always cards you tick, never a paragraph you have to trust.
- **Two surfaces, a door in each direction.** The assistant is where you decide, plan, ask and check in, across everything, in one thread. Every matter has a status view where you drill down — open the files, see what is actually in Reminders, read the history. Each matter the assistant mentions is a door into its status view; every row of a status view has a door back into the assistant with that item already in hand. Neither surface is a mode you enter and leave.
- **Only one door leads out.** From either surface, a tap of yours is the only thing that writes to Reminders or Calendar or opens a message in Mail. Nothing leaves on its own.
- **Nothing is learned invisibly.** When Matterbee picks up a standing rule from something you said, that rule appears in a list with where it came from, how often it has fired, and a switch. An agent that learns behind your back is one you stop trusting the first time it is wrong.
- **Matterbee drafts, you send.** It writes messages and opens them in Mail or WhatsApp with the text in them. It never sends, and the send button is always yours. This is the read-only rule pointed outwards.
- **Mail is one door, not the building.** A matter can start from a sentence you speak in the car, a photo of a notice, or a note after a phone call. Email intake is the biggest door, not the only one.
- **The interface has a language; the content keeps its own.** The app's words — buttons,
  labels, hints — are in one language the owner chooses. Everything that comes from a mail, a
  chat or a document — to-dos, digests, dates, roles, names of matters — stays in the language
  that source was written in, and is never translated: a German mail gives German to-dos, an
  English one English ones, whatever the interface is in.
- **Swift first.** Core logic lives in a Swift package (`MatterCore`) shared by the CLI, the Mac app and the iPhone app.
- API key is read from an environment variable or the Keychain, never committed.

---

## Two editions: you choose first, the whole inbox later (decided)

Matterbee ships first as the edition where **you decide what goes in**, and gets a second,
fully automatic edition on top of it once the first has proved itself in daily use.

**Matterbee (manual).** While reading your mail as you do anyway, you put one label on the mail
that starts something — a Gmail label or an IMAP folder, the same thing over IMAP. Only labelled
mail is read, disguised and sent. Replies in a thread that already has a matter follow it on
their own, by `In-Reply-To`, `References` and subject, so a thread is labelled once, not once per
reply. **One label, not one per matter:** the model assigns the matter among the ones you have,
or proposes a new one, and you correct it where it is wrong. One label is one thing to remember
every day; a folder per matter would make every tap a decision.

**Matterbee Pro (automatic).** The same core with a sweep in front of it: every mail past the
bulk filter is looked at, and matters are suggested before you have noticed them. This is where
question 5 of the spike — can a matter be seen forming — belongs.

Why this order, from the spike's own runs on 236 real mails:

- **The effort is small.** Labelling the first mail of each matter thread was 53 taps over 23
  weeks, about two a week; 130 further mails reached their matter by thread alone, none wrongly.
- **The cost is where the noise is.** Reading everything with Claude Opus 5 came to $0.043 a
  mail and with Claude Haiku 4.5 to $0.0045. At thirty mails a day that is about $39 or $4 a
  month; labelled mail only, about six a day, is about $8 or under $1.
- **So the better model becomes affordable.** When most of the money is spent reading noise,
  the choice is forced towards the cheap model. When every mail sent is one you chose, the
  stronger model fits a budget of ten euros a month, and the stronger model is the one that
  found 30 of 31 labelled matters against 25.
- **Every tap is ground truth.** A label says "this matters to me", which is the signal Pro will
  need to learn and to be measured by. The manual edition collects it in daily use, without a
  labelling evening.
- **Nothing is thrown away.** Disguise, extraction, restore, thread memory and matters are the
  same in both. Pro adds a door; it does not rebuild the house.

The one thing the manual edition cannot do is notice what you did not label. The thread rule
covers replies; a first mail you did not label stays outside until you do.

---

## Phase 0: Spike — how does the AI decide?

**Goal:** understand and measure the decision pipeline on real emails before building any UI. Output is a report, not a product.

**Duration:** 1–2 weeks, part-time.

### Setup

- A macOS command-line tool in Swift: `matter-spike`, using the `MatterCore` package.
- Input: a folder of `.eml` files exported from Mail (select emails, drag into Finder). No IMAP yet.
- Dataset: ~150 emails from the last 3 months. Mix of the Hausverwaltung thread, newsletters, notifications and unrelated personal mail.
- Golden set: a hand-labeled `labels.csv` with, per email: `is_bulk`, `matter` (or none), `parties`, `todos`, `deadlines`. Label ~50 emails; that's enough to see patterns.

### What the spike builds

A pipeline where every stage writes to a decision log (`decisions.jsonl`):

1. **Parse.** Read `.eml`: headers, body text, attachments list.
2. **Bulk filter (rules, no AI).** Use `List-Unsubscribe`, `List-Id`, `Precedence: bulk`, noreply senders.
3. **Entity detection (on-device).** Apple `NaturalLanguage` (`NLTagger`, German) for names, places, organizations, plus regex for email addresses, phone numbers, IBANs, street addresses.
4. **Pseudonymize.** Replace entities with stand-ins, store the mapping locally (`mapping.json`, gitignored). Two modes to compare:
   - `placeholder`: `[Person A]`, `[Company B]`
   - `standin`: realistic same-type replacements (Prenzlauer Berg → Friedrichshain; conditions generalized, not swapped)
5. **Classify and extract (Claude API).** Send the disguised text with a short matter summary. Ask for structured JSON (schema below).
6. **Restore.** Swap the originals back into the result.
7. **Cluster.** Across all emails, group non-bulk emails into candidate matters by shared entities, terms, threads and cc patterns. Output suggested matters with their member emails.
8. **Report.** Compare the results against the golden set.

### Decision output schema (per email)

```json
{
  "email_id": "string",
  "is_bulk": true,
  "bulk_reason": "List-Unsubscribe header",
  "matter": "hausverwaltung | null | new_matter_suggested",
  "matter_confidence": 0.0,
  "matter_reason": "one line",
  "decided_by": "rule | on_device | claude",
  "parties": [{ "name": "string", "role": "string", "is_new": true }],
  "todos": [{ "text": "string", "owner": "me | other | unknown", "due": "YYYY-MM-DD | null", "source_quote": "short excerpt" }],
  "deadlines": [{ "what": "string", "date": "YYYY-MM-DD", "source_quote": "short excerpt" }]
}
```

`source_quote` is required so every extracted fact can be traced back to the text.

### Questions the spike must answer

| # | Question | How to measure |
| --- | --- | --- |
| 1 | How much does the rules-only bulk filter catch? | % of bulk emails caught, false positives |
| 2 | Does on-device entity detection find German names, places and companies well enough? | Missed entities per email (each miss is a privacy leak) |
| 3 | Do stand-ins keep Claude's accuracy better than placeholders? | Extraction accuracy, `placeholder` vs `standin` |
| 4 | How good is to-do and deadline extraction? | Precision and recall vs golden set |
| 5 | Can clustering spot a matter forming without being told? *(Pro)* | Does the Hausverwaltung matter emerge from the mix? |
| 6 | Which model is good enough? | Compare a fast model and a stronger model on accuracy, cost and latency per email |
| 7 | What does it cost per email and per month? | Tokens × price, at the expected volume |

Check current model names and pricing in the Anthropic docs before running.

With the manual edition first, questions 2, 4, 6 and 7 are the ones that decide it, and they are
measured on the mail you would label — the matter mail — rather than the whole folder. Question 5
moves to Pro, and question 1 matters less: in the manual edition the bulk filter only decides
what a thread reply may bring in, not what is read.

### Exit criteria

- A `SPIKE_REPORT.md` with the answers to all seven questions, examples of good and bad decisions from the log, and a recommendation.
- A go/no-go on the privacy approach: if on-device detection misses too much, decide on a fallback (e.g. a dedicated on-device NER model or stricter redaction) before Phase 1.
- A chosen prompt and schema, versioned in `MatterCore/Prompts/`.

### Suggested first prompt for Claude Code

> Read PLAN.md. Set up a Swift package `MatterCore` and a macOS CLI `matter-spike` for Phase 0. Start with steps 1–3 (parse `.eml`, rules-based bulk filter, on-device entity detection) and write each decision to `decisions.jsonl`. No API calls yet. Show me the log for a sample folder before moving on.

---

## Later phases (after the spike)

Keep these as outlines; refine them based on the spike report.

### Phase 1: Core model

- SwiftData models in `MatterCore`: Matter, Phase, Party, Entry, Todo, Deadline, Document, **Decision**, **Rule**, **Draft**.
- **Decision is a first-class entry, not a note.** "Thermotec bekommt den Auftrag, weil sie als Einzige bis 31. Okt gebunden sind" is the thing you will be asked about in six months and the thing no mailbox records. It carries what was decided, why, when, and what it was decided from.
- **Name collision to settle here:** the spike already has a `Decision` type, and it means something else — the pipeline's own audit record of which layer concluded what. Rename that one (`Judgement`) before Phase 1 adds the user-facing kind, rather than discovering the clash halfway through.
- **A to-do has an owner, and there are three.** Mine, ours — the owner together with others, the
  owners of a building acting as one — and someone else's that I am waiting for. Someone else's
  task that I am not waiting for is not a to-do, and is not shown: the list stays the owner's list.
  Decided from the spike, where a model that listed everybody's tasks made the list long and
  "me or someone else" could not say who calls the owners' meeting.
- **Entry has a source, always.** Mail, a spoken note, a photo, a phone call, a document. Every entry in a timeline says which, because that is what makes the history checkable.
- **Rule** is a standing instruction the user gave: how to read something, where mail goes, what a word of theirs means. It records its origin, a fire count, and an on/off switch — see the ground rule.
- *Started (Phase 2, before the app):* Matter, Entry, Todo, Appointment, Deadline, Party and
  Decision in SwiftData, CloudKit-ready (defaults everywhere, optional relationships, nothing
  unique); `Source` on every fact; the spike's `Decision` renamed `Judgement`; import from a log,
  safe to repeat; merge and rename with aliases. Not yet: Phase, Document, Rule, Draft, sync,
  and merging two parties that are the same company written two ways.
- Phase templates (Hausverwaltung: inform → request offers → compare → decide → hand over; application: apply → wait → accept → contract).
- CloudKit sync, with sensitive fields encrypted.
- The pseudonymization mapping stays in local, non-synced storage per device (decide in spike whether it needs syncing).

### Phase 2: Mac app, manual intake

- The two surfaces from the design section: an assistant thread, and a matter status view with
  to-dos, deadlines, files, parties and history. Build the door in each direction from the
  start — a status row that cannot open a scoped conversation is a dead filing cabinet, and an
  assistant with nowhere to drill into is a chatbot.
- Matter list and matter overview (phase, next steps, open to-dos, deadlines, parties).
- **Intake, the daily door: one label.** Read-only IMAP (and Gmail's labels, which IMAP shows as
  folders) for a single Matterbee label or folder, fetched on demand. Thread replies follow a
  labelled mail by `In-Reply-To`, `References` and subject. This moved here from Phase 4: the
  manual edition is the product, and this is how it is used every day.
  *Started first, in `MatterCore` and as `matter-spike fetch`:* a read-only IMAP client, the
  password in the Keychain, and replies found by Gmail's thread id (`X-GM-THRID`) or by
  `References`. Subject alone is not used to fetch a mail — too many threads share one.
- Intake besides mail: Share from Mail, drag and drop `.eml` and files, iCloud Drive matter
  folder watching.
- "Make a matter" from any email, pulling related history backwards.
- **"Make a matter" from nothing:** say or type what it is, Matterbee names it, picks a phase template and explains why it picked that one, then sweeps backwards through mail already on the device for anything that looks like it. Same machinery as the line above, started from the other end.
- Preview of disguised text before any API call.

### Phase 3: iPhone app and outputs

- Same matter views on iPhone.
- Share extension for Mail and screenshots (Vision OCR on-device).
- **Attachments in the assistant:** photo, document scan, Files, and the recent-screenshots
  shortcut, straight onto the composer. PDFKit for a text layer, Vision for everything else,
  both on the device. Per-page reporting, because "I read pages 1–2 and page 3 is a scan" is
  the difference between a missing number and a wrong one.
- **Speaking into it.** One utterance can carry several things of different kinds — a decision, a message to write, a reminder — and each comes back as its own card. This is Utterstar's engine with matters as the context; copy it in rather than depend on it, the same way Utterstar copied from Utterclip. The one new question is which matter an utterance belongs to, and that is a picker with a reason on it.
- EventKit: confirmed to-dos → Reminders list per matter; deadlines → Calendar. Two-way completion sync.

### Phase 4: Matterbee Pro — the whole inbox

- The whole mailbox, not one label: the same read-only connection, every folder.
- Triage layers: bulk filter → known parties → threads → vocabulary scoring → Claude for unclear
  emails. The sweep is the cost: reading everything past the filter with a language model costs
  what automatic classification costs, so a sweep earns its place only with a cheap first pass
  in front of it — senders who have gone quiet, mail from people rather than companies, or a
  yes/no decision model.
- Emerging-matter suggestions and new-party suggestions in a triage list, measured against the
  labels the manual edition collected.
- Gesture intake stays: a Mail flag colour or a folder still says "this one" when the sweep did
  not.

### Phase 5: Summaries, comparison and outgoing drafts

- Offer comparison table filled from offers. A cell that could not be read says so and points at the page — an empty cell is honest, an invented price is not.
- **"Worth writing":** the one view that looks forward. Silences with a date on them — "Kruse has not sent a price, 8 days, and it is the one hole in your comparison" — each naming what it is waiting on and who it would go to.
- **Drafts made of ticks.** A draft is assembled from facts you tick; untick one and its sentence goes. Matterbee may also arrive with a fact already unticked and a reason ("this would tell Kruse what the competition charges") — a tick, never a rule, because it can be wrong about that.
- Hand-off to Mail or WhatsApp, or the clipboard. Matterbee never sends.
- Voice note intake.

---

### Phase 6: Instructing it, and what it remembers

- **Correcting in place.** A field on any card that got it wrong. You say what is actually the case, in whichever language comes out, and what comes back is cards: change this, keep that, and — when the correction is the kind that would recur — an offer to remember it.
- **Asking about a matter.** A question field scoped to one matter, stating on screen which entries it can see. Every line of an answer cites the entry it came from, and anything the answer implies arrives as a card with a tick rather than as advice.
- **The rules list.** Everything Matterbee has learned, in three groups: how to read things, where mail goes, and words you use. Each with its origin, its fire count, and a switch.
- A rule is only ever made from something the user said, and only after a correction has recurred or been explicitly offered. Nothing is inferred from behaviour alone.

---

## Design

Wireframes: the **Matterbee — Wireframes** page in the Figma file (`PRKED8BlyD3FVaglwhKRy1`,
page `23:2`). Low fidelity, every frame captioned with what it is for and which ground rule it
keeps.

### The shape (decided)

Four frames at the bottom of the page, marked DECIDED:

- **C1 · Assistant** — deciding, planning, asking and checking in, over all matters, one thread.
  Each matter it names is a door into that matter.
- **C2 · Matter status** — the reference surface and a real place: phase, to-dos carrying their
  actual Reminders state, deadlines, files to open, parties, history. Every row has "reden".
- **C3 · The same chat with one item in hand** — what "reden" opens. The item is pinned above
  the field and can be taken off; you never have to describe what you mean.
- **C4 · The map** — the two surfaces, the door in each direction, and the single outward door.
- **C5 · Attach a screenshot or a PDF** — anything goes into the assistant: a PDF, a screenshot
  of a WhatsApp thread, a photo of a letter. It is read on the device first and says what it
  read and what it could not.
- **C6 · What it made of them** — the file becomes cards, each citing a page and line or the
  time on the screenshot, including cards that *change* something that already exists.
- **C7 · A WhatsApp screenshot, read properly** — the thread re-rendered with speakers and
  times, what is cut off above said out loud, and a to-do closed by somebody else's message.

The Figma page is grouped into three sections: **The shape — decided**, and the two
explorations underneath it.

### The explorations it came from

Both are kept on the page because the arguments in them are still the arguments.

- **Exploration A — process first.** Matters and Triage are the app, with the capture bar over
  them. Sixteen screens: the matter views, intake, the disguise preview, the confirm step,
  offer comparison on Mac, correcting in place, the rules list, outgoing drafts, speaking
  things in, starting a matter with no email, the timeline. Most of these screens survive as
  drill-downs under C2 and as things the assistant opens.
- **Exploration B — conversation first.** The app opens talking, mail lands in the thread, and
  lists are transient answers. B's spine won; **B's disposable lists did not** — to-dos live in
  a matter's status view and stay there, which is what makes them findable when the assistant
  never mentioned them.

---

## Open questions

- ~~One Matterbee label, or one per matter?~~ **Settled:** one label; the model sorts it into
  matters and the user corrects.
- How does a mail the user forgot to label come back into view in the manual edition — never,
  or through a weekly "these look related to a matter you have" suggestion that costs a sweep?
- ~~Where do the IMAP credentials live, and does Gmail need OAuth rather than an app password?~~
  **Settled for now:** a Gmail app password, in the Keychain. OAuth can come later, for the app,
  if app passwords become a problem.

- Which mail accounts carry the Hausverwaltung matter?
- Should the pseudonymization mapping sync between iPhone and Mac, or be rebuilt per device?
- Is the preview before sending always shown, or only when new entities are found?
- What happens to a closed matter and its mapping: archive, export, delete?
- Where does capture live on iPhone — a tab, the share sheet, a widget, the Action button, or all of them?
- ~~Does "ask about this matter" reach across matters?~~ **Settled:** yes, and that is the
  assistant. Scoping is a chip on the composer, not a different screen.
- The status view shows a to-do's real Reminders state, which means reading it back. What does
  it show when Reminders access was never granted, or the list was deleted in Reminders?
- ~~Does the assistant thread have an end?~~ **Settled:** no. One thread since the first
  question, kept beside the store; scrolling up shows everything, with the day where it
  changes. With a matter open, the assistant shows that matter's part of it.
- A referenced file can move or be deleted outside the app. Does a matter show a dead pointer,
  re-ask, or quietly copy the file in the first time it is opened?
- ~~A WhatsApp screenshot gives words with no verifiable sender.~~ **Wrong:** a chat screenshot
  carries group, participants, speaker, minute and delivery ticks. What it does *not* carry is
  an address behind a display name, and it can be cropped or edited — so the open question is
  narrower: is a party created from a display name alone marked provisional until confirmed?
- A chat message often points at another channel — "habe Euch die Mail geschickt". Should
  Matterbee go and find that email in the mailbox and attach it to the same matter, and how
  sure does a match have to be before it does?
- A photographed receipt (Einlieferungsbeleg, Einschreiben) is evidence with a date on it.
  Does a matter need a "proof" entry type, separate from documents, for the things that exist
  to show something happened on a particular day?
- When a learned rule turns out to be wrong, is it switched off or corrected? A switch is simpler; a correction is what a person would actually want.
- A WhatsApp draft cannot read the thread it is replying to. Does Matterbee say so, or stay out of WhatsApp?
- Do decisions need their own review — "what did I decide and why" across all matters — or is the per-matter timeline enough?
