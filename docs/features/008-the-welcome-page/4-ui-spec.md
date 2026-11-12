# F008 · The welcome page — Looks

## Screens and states

The picture is `wireframes.html` in this folder (published as "Welcome and First Step", https://claude.ai/artifact/NcysvcZN8tTbcSt9jsggrr). Five places:

**1 · The welcome** — a sheet on every device, as today, now four pages instead of six:

| Page | What it shows |
|---|---|
| 1 · The promise | The bee; "Every matter. In its place."; one line; one example matter as the overview shows it (today's `sample`); under it the privacy line, once, with a lock |
| 2 · A matter's page | One cut-out of a demo matter: the Next card and two tasks — not the whole screen. Title and one line |
| 3 · From whatever you have | A screenshot on the left, the two things found in it on the right. Title and one line |
| 4 · Ask about it | One question and its answer with a source. Title and one line |

The foot: the dots; **Next** (filled) and **Skip** on pages 1–3; **Start** (filled) on page 4. Skip and Start both end the welcome. Nothing else on the last page: the iCloud / Plan / Mail ticks go.

A picture is a cut-out — one part, about 240 points high on the iPhone, a third of the sheet on the Mac — framed as today's (rounded, a thin line, a soft shadow). Never a full screen.

**2 · The first step** — the overview while there are no matters, on a first start and after the last matter is gone. In the middle of the overview, one column (520 points at most):

- the bee, small;
- the title "What's on your mind?";
- one line: "Type it in a few words, or add what you have.";
- the field, on glass as the chat's field, three lines high, growing to six, with the send button at its end;
- under it, three quiet buttons: Photo, Scan, File — on the Mac one button, "Add a file …", and "or drop it here";
- under them, apart, a link: "Not sure yet? Look around in an example."

| State | What shows |
|---|---|
| Empty field | Send is greyed |
| Typed | Send is the yellow `SendGlyph` |
| Reading | The field greyed with the words in it; under it the bee working and "Reading …"; then the matter opens |
| Added | The file's picture small in the field's place, "Reading …"; then the matter opens |
| Looking in iCloud (AC-10) | Above the title: a small spinner and "Looking in iCloud for your matters …"; the first step under it as always. Matters come: the overview. Thirty seconds and nothing: the line goes |
| A file Causabee cannot read | Under the buttons: "Causabee can't read this file." The step stays |
| Without Pro | The same; nothing on the screen differs |
| Long text | The field scrolls after six lines |
| Large type | The column scrolls; the field and the buttons stack |

**3 · The first matter, just made** — as any matter's page, with one addition while no name is known (AC-12): a quiet box at the top, over the Next card:

- Mac: "This is you: Alex?" — **Yes**, *Change* (Change turns the name into a field with **Save**)
- iPhone and iPad: "Your name, so your tasks show as yours." — a field "Your name" — **Save**

Saved: the box goes, on every device. The matter that could not be read has, under its title: "Not read yet — your words are kept."

**4 · The mail card** (AC-8) — on the overview, under the last matter, while no mailbox is set up and Not now has not been tapped:

- "Also what comes by mail?"
- "Causabee reads one label or folder you choose — nothing else in your mailbox."
- **Set up** (quiet) and *Not now* (a link). Set up opens today's mail setup.

Grey card on white, no yellow, no badge, no count.

**5 · The Mac's start** — after the welcome, no setup sheet opens. Causabee → Set Up Causabee … stays in the menu.

## Words

| Where | Text |
|---|---|
| Promise, title | Every matter. In its place. *(as today)* |
| Promise, line | Mum's care, a claim, a move: each in its own place — with what comes next, and who does what by when. *(as today)* |
| Privacy, once | Names are disguised before anything is sent. |
| Page 2, title | One page for each matter |
| Page 2, line | What comes next, and who does what by when. |
| Page 3, title | From whatever you have |
| Page 3, line | A screenshot, a photo, a letter, a few words: the bee finds the dates and the tasks. |
| Page 4, title | Ask about it |
| Page 4, line | Ask, and get an answer with where it came from. |
| The foot | Next · Skip · Start |
| First step, title | What's on your mind? |
| First step, line | Type it in a few words, or add what you have. |
| The field, empty | Mum's care, a claim, a move … |
| Buttons, iPhone and iPad | Photo · Scan · File |
| Buttons, Mac | Add a file … · or drop it here |
| The demo | Not sure yet? Look around in an example. |
| Reading | Reading … |
| iCloud | Looking in iCloud for your matters … |
| Unreadable | Causabee can't read this file. |
| Not read | Not read yet — your words are kept. |
| Name, Mac | This is you: Alex? · Yes · Change · Save |
| Name, iPhone and iPad | Your name, so your tasks show as yours. · Your name · Save |
| Mail card, title | Also what comes by mail? |
| Mail card, line | Causabee reads one label or folder you choose — nothing else in your mailbox. |
| Mail card, buttons | Set up · Not now |

Checked against the house rules: short sentences, few words. Page 3 and the first step name every way in; mail is named only on the mail card, which is about mail alone. The empty overview no longer says "Set Up Causabee … to bring in your mail" or "Pull down to get new mail".

## On each device

- **The same everywhere:** the four pages, every word, the first step's order, the name box, the mail card.
- **iPhone:** the welcome full-screen as today; the first step fills the overview under the search field, which stays.
- **iPad:** the welcome as a large sheet; the first step in the overview's column, the sidebar beside it as today.
- **Mac:** the welcome as today's sheet with its pictures wider (the Mac's own cut-outs); the first step in the overview where "No matters yet" stood, which goes; one "Add a file …" button and the window's drop instead of three buttons.

## Undo, and what the user can take back

- The first matter is an ordinary matter: renamed, merged or deleted as any. Deleting it brings the first step back.
- A name saved can be changed in Settings (iPhone, iPad) or in About you (Mac).
- Not now on the mail card: the mail setup is always in Settings, and in Causabee → Set Up Causabee … on the Mac.
- The welcome again: ⋯ → Introduction (iPhone, iPad), Help → Introduction to Causabee (Mac).

## Accessibility

- VoiceOver: the field "What's on your mind?"; Send "Send"; the buttons "Add a photo", "Scan a document", "Add a file"; the demo link "Look around in an example"; each picture hidden, its title and line read; the dots "Page 2 of 4", as today.
- Large type: everything wraps, the column scrolls; the buttons stack under one another.
- Dark mode: the tokens' own dark values; the pictures taken in both modes, as today.
- Targets: 44 points on touch; the demo link too.
- Reduce motion: no slide between pages, as today.

## Design system

- **The welcome:** `BeeMark`, `Theme.phoneTitleFont`, `.phoneCard()` for the example matter, `BeeChip` on it (as today); the privacy line as today's lock line on `Theme.box`; the foot's `.phone(filled:wide:)` / `.filledButton()`.
- **The first step:** the field with `.glassBehind(RoundedRectangle(cornerRadius: 24))` and `SendGlyph`, as the chat's (G1); `MicButton` in the field, as in the chat; the add buttons `.quietButton()`, built on the iPhone's existing `AttachButton`; the demo `.buttonStyle(.gold)`; "Reading …" with the bee working (`BeeLoader`).
- **The name box:** `.phoneBox()` on the iPhone and iPad, `.quietBox()` on the Mac; Yes / Save `.filledButton()`, Change `.buttonStyle(.gold)`.
- **The mail card:** `.phoneCard()` / `.journalCard()`; Set up `.quietButton()`, Not now `.buttonStyle(.gold)`.
- No new colour, font or part type. `FirstStep`, `NameLine` and `MailOffer` are views made of the parts above, shared by both apps (C4).

## Picture

`wireframes.html` in this folder: the four pages, the first step in its states, the name box, the mail card — iPhone and Mac, light and dark.
