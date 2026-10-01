# A day with Matterbee — storyboard for the portrait film

> Superseded on 1 October 2026 by docs/film-script.md: a narrated 90-second script, one drawn
> object per spoken line, instead of recorded screens. This file keeps the scene research, the
> recording tools' notes and the draft's lessons.

A vertical film (9:16, 1080 × 1920) of about 75 seconds. It walks through one everyday round in
Matterbee, zoomed in close: the mail comes in, gets sorted, and the matter page, the tasks, the
dates, the files and the assistant each get their moment. One story carries it all: Care for Mum
(Helga) after her fall, the matter the website and the demo lead with.

The day moves between the two devices. Morning at the desk, on the Mac: the mail round. Midday
out, on the iPhone: at the doctor's, at Mum's flat. Evening at the desk again, on the Mac: the
matter page, the tasks, the assistant. What is done on one shows up on the other, through your
own iCloud, and the film shows that each time it happens. No feature appears twice.

Rules for every scene

- Real screens only. Every frame is a crop of the demo app (Mac or iPhone), as the website's pictures are.
- Zoomed in. A scene shows one thing, big: a card, a button, a line of text, the bee. Never the whole window.
- One caption per scene. A short line in Source Serif at the bottom third, in the website's words. No voice-over for the first cut.
- The bee is the thread. It appears whenever Matterbee works, and nowhere else.
- Light mode throughout. One dark-mode flash in scene 1 only (ink in the light, honey in the dark).
- Content keeps its language: the demo is English, so the film is English.

Timing is a first guess. The fast scenes are 3 seconds, the ones with reading are 6 to 8.

---

## 1 · The bee wakes up · 4 s · both

**We see** the app icon, filling the frame on the yellow. The six stripes drop in one after
another from the top, the wings beat twice, the bee settles (the website's hero animation).
Then a cut to black for half a second with the honey-coloured bee, then back to light.

**Caption** Every matter. In its place.

**Source** site/index.html hero icon (CSS keyframes `icon-sort`, `icon-wl`, `icon-wr`).

## 2 · Morning: the overview · 6 s · Mac

**We see** the overview, zoomed on the Care for Mum card. The camera drifts slowly down the card:
the name, the next step "Read and sign the Sunrise contract", the line "Overdue · Collect the bath
seat prescription at Dr. Brandt's", "Waiting for · Uncle Karl". Other cards are blurred at the edges.

**What moves** a slow zoom, nothing else. The reader gets time.

**Caption** Mum's care: the doctor, the insurer, the care service, your sister.

**Source** `--demo --shot overview`, cropped to the care card.

## 3 · Get new mail · 6 s · Mac

**We see** the toolbar button "Get new mail", a cursor clicks it. The small text "Fetching mail …"
with the bee working beside it (stripes sorting, wings beating). Then the result list grows in:

> 2 new mails
> • Prescription for the bath seat is ready
> • Re: Who does what this week?
> Sorting in costs about $0.02. Sent pseudonymised to Claude Opus 5.
> Cancel   Sort in

**What moves** the click, the bee, the lines appearing one by one, the cursor resting on "Sort in"
but not clicking yet.

**Caption** Nothing is sent until you click Sort in.

**Source** Sources/Matterbee/MailCheck.swift, as the website's "live" fetch stage.

**Note** the demo's round brings three mails, for Lisbon, the move and the wedding (DemoData.newMail),
and says "In the demo, sorting in sends nothing and costs nothing." The draft shows those. For the
final film we either give the demo a care round (the two mails the website's hero fetches), or
render this panel from a made-up Look with the real cost line. To decide after the draft.

## 4 · What the AI sees · 7 s · Mac

**We see** one sentence from the new mail, large, on a white card:

> Dr. Brandt has the bath seat prescription for Helga.

The names glow gold for a moment, then swap in place:

> [Person A] has the bath seat prescription for [Person B].

A small label slides in above: "On your Mac" becomes "What the AI sees".

**What moves** only the two names. Everything else holds still, so the eye lands on the swap.

**Caption** Names, addresses and numbers are replaced on your Mac first. If the disguise can't be built, nothing is sent.

**Source** the website's "Private by design" pair (On your Mac / What the AI sees).

## 5 · Sort in · 6 s · Mac

**We see** the cursor clicks "Sort in". "Sorting 2 mails …" with the bee. Then the result line:

> 2 mails sorted into Care for Mum (Helga) after her fall · 1 new task · $0.012

Then a cut into the matter's thread, where the history line appears:

> 📥 2 mails taken in · 2 new tasks · sorted by Claude Opus
> • Please have these documents ready for the visit
> • Prescription for the bath seat is ready

**What moves** the bee, then the line writes itself, then the thread line fades in.

**Caption** Sorted into the matter it belongs to. Every answer shows what it cost.

**Source** MailCheck.swift result; DemoData `c.note(-1, "📥 2 mails taken in …")`.

## 6 · The next step · 6 s · Mac

**We see** the top of the matter page, zoomed on the status card:

> The next step
> Read and sign the Sunrise contract
> It has to be back by 2 October for the first visit on 7 October.

Below it the summary, with "Writing the summary …" and the bee for a second, then the three
lines of the summary appear.

**What moves** the bee, then the summary text. The next step is already there and holds still.

**Caption** One thing to do now, and why it can't wait.

**Source** `--demo --shot care` (intro-5), top of the page; the website's "Writing the summary …" stage.

## 7 · Midday, at the doctor's · 7 s · iPhone, then Mac

**We see** an iPhone in a hand, the Care for Mum screen. At the top, the overdue task:

> Collect the bath seat prescription at Dr. Brandt's · Overdue

A thumb ticks it. It fades. The next step moves up.

Cut to the Mac at home, the same task row in the list: it is done there too, the tick appears
by itself.

**What moves** the tick on the phone, then the same tick arriving on the Mac.

**Caption** Tick it on the phone. The Mac at home knows. Your matters sync through your own iCloud.

**Source** iPhone simulator with the demo (Sources/MatterbeePhone/MatterScreen.swift); the Mac's task list.

## 8 · At Mum's flat: a letter · 8 s · iPhone

**We see** a letter from the care fund on the kitchen table. The phone's ⋯ menu, "Scan". The
camera frames the page, the corners snap. The scan slides into the thread: "Scanning it on this iPhone …" with the bee,
with the text shown, the names already disguised. "Sort in", the bee, and a card:

> Deadline · Send the signed contract to Healthbridge · by Oct 15
> Take into Care for Mum

A tap. The card folds into the matter.

**What moves** the camera, the scan sliding in, the bee, the card.

**Caption** Scan a letter, and it goes into the matter. The paper stays on your phone.

**Source** Sources/MatterbeePhone/Scans.swift and PhoneShots.swift. The letter to print: docs/film/healthbridge-letter.png.

## 9 · A mail on the way home · 5 s · iPhone

**We see** the iPhone's Mail app, a mail from Nina: "Thursday: can you take it? I have the
dentist." The share button, the share sheet, Matterbee in it. A tap. The Matterbee sheet: "Care
for Mum" found, "Sort in". Done: "Task · Cover Thursday for Nina · Yours · by Oct 8".

**What moves** the share sheet rising, the tap, the result.

**Caption** Share any mail to Matterbee. It finds the matter it belongs to.

**Source** Sources/MatterbeeShare (the share extension) and Sources/MatterbeePhone/SharedIn.swift.

## 10 · Evening: who does what · 8 s · Mac

**We see** the task list of the care matter on the Mac, zoomed on two rows:

> ○ Read the Sunrise contract together with Nina · Shared · by Oct 2
> ○ Sign the Sunrise contract and send it back · Yours · waits for the one above

The cursor ticks the first. It fades. The second row lights up: "its turn now".

Then a short pan across the pills: Yours · Shared · Waiting for · the one with "Uncle Karl". The
task from Nina's mail (scene 9) is in the list now, with "Yours · by Oct 8".

**What moves** the tick, the fade, the "its turn now" glow, the pan.

**Caption** Tasks are yours, shared, or someone else's you're waiting for. Some can only start after another.

**Source** `--demo --shot lisbon-tasks` style, on the care matter (new shot name `care-tasks`); the website's "Who does what" stage.

## 11 · Every fact has a source · 6 s · Mac

**We see** the task row "Sign the Sunrise contract and send it back". The cursor hovers its quote
mark. A card opens with the mail:

> Contract draft: please sign and return by 2 October
> Yusuf Kaya · Sunrise Home Care
> "… if the signed contract is **back by 2 October**."

The quoted words are marked gold. A small button: "Open the mail in Mail".

**What moves** the card opening, the gold mark drawing itself along the words.

**Caption** Each task and date links back to the mail it came from.

**Source** `--demo --shot care`, lower half (the website's "sources" crop).

## 12 · Calendar and Reminders, in step · 6 s · Mac

**We see** the date row "Assessment visit (medical service) · Tue 6 Oct · 10:00 · Mum's flat".
The chip "Add to Calendar" is clicked. It turns into "In Calendar" with the calendar icon.

Then a cut to the Mac Calendar app, zoomed on that event. The time is dragged to 10:30. Cut back:
the row in Matterbee now reads 10:30.

**What moves** the click, the chip changing, the drag in Calendar, the time updating in Matterbee.

**Caption** Change it in either place, and the other follows.

**Source** the website's "calendar" crop; for the Calendar app half we record the real Calendar window.

## 13 · Files, links and people · 5 s · Mac

**We see** the matter's side column, zoomed. The paperclip with "3", and under it:

> Doctors-report.pdf
> Hospital-discharge-letter.pdf
> Sunrise-contract-draft.pdf

A pan down to the people, each with a role:

> Nina Voss · Sister, shares the care
> Dr. Anselm Brandt · Family doctor
> Yusuf Kaya · Sunrise Home Care
> Healthbridge Care Fund · Health insurer

**What moves** a slow pan only.

**Caption** Files, shared documents and everyone involved, each with their role.

**Source** `--demo --shot lisbon-files` style, on the care matter (new shot name `care-files`).

## 14 · Ask about the matter · 10 s · Mac

**We see** the assistant's field, gold while typing:

> What do I need to do before Tuesday's visit?

Return. "Matterbee is on it …" with the bee. The answer comes in three lines, each with a small
source mark (T1, T2, T3):

> Put the medication list, the doctor's report and the hospital letter together; the insurer asked for them twice.
> Move the physio that day to the afternoon: the visit starts at 10:00 and may run into the 11:00 slot.
> Also still open: the signed Sunrise contract, due back on 2 October.

Then a suggestion card:

> Ask a neighbour to be at Mum's flat by 09:45 on 6 October
> A family member should be there, and Mrs. Adler has the spare key.
> [Take in]

The cursor clicks "Take in". The card becomes a line: "Task added · Waiting for · by Oct 5 · Undo".

**What moves** the typing, the bee, the three lines, the card, the click, the line.

**Caption** Ask in your own words. The answer shows its sources, and a good suggestion becomes a task in one click.

**Source** DemoData `c.ask(0, "What do I need to do before Tuesday's visit?" …)`; the website's "live--ask" stage.

## 15 · The overview, calmer · 6 s · Mac and iPhone

**We see** the overview card from scene 2, same crop. It is calmer now: the overdue line is
gone, the next step reads "Put together the documents for the visit", the task count is lower.
The camera pulls back until the whole overview is in frame, and an iPhone slides in beside the
Mac, showing the same card.

**What moves** the lines changing in place (a cross-fade), the pull-back, the phone sliding in.

**Caption** The next step is always clear. On the Mac, and on your iPhone.

**Source** `--demo --shot overview` twice, before and after the round; the iPhone's overview from the simulator.

## 16 · Close · 4 s

**We see** the icon again, still. Under it:

> Matterbee
> Free and open source · for Mac and iPhone
> ralfchille.github.io/matterbee

**Caption** none.

---

## What it adds up to

| Scene | Seconds | Device | What it shows |
| --- | --- | --- | --- |
| 1 | 4 | both | the bee, the name |
| 2 | 6 | Mac | the overview card |
| 3 | 6 | Mac | Get new mail, the cost line |
| 4 | 7 | Mac | the disguise |
| 5 | 6 | Mac | Sort in, the history line |
| 6 | 6 | Mac | the next step, the summary |
| 7 | 7 | iPhone → Mac | tick a task out and about; it arrives at home |
| 8 | 8 | iPhone | scan a paper letter |
| 9 | 5 | iPhone | share a mail from Mail |
| 10 | 8 | Mac | tasks: whose, waits for |
| 11 | 6 | Mac | the source of a fact |
| 12 | 6 | Mac | Calendar both ways |
| 13 | 5 | Mac | files and people |
| 14 | 10 | Mac | ask, sources, suggestion → task |
| 15 | 6 | both | the overview, calmer |
| 16 | 4 | | close |
| | **100** | | |

Six of the sixteen scenes are on the iPhone or show both. Each scene also stands alone as a
5-to-10-second clip, so the same material can be posted one scene at a time.

## Decided (1 October 2026)

- About 95 seconds, 16 scenes, Mac and iPhone together.
- Captions only in the film. A voice-over script is below, for ElevenLabs, as a second version.
- Music: very quiet, under the bee only. It swells a little while the bee works and is gone when the reader reads.
- The paper letter is scanned with the iPhone's camera (scene 8), so no chat screenshot is needed. docs/film/healthbridge-letter.png is the letter to print; healthbridge-letter-photo.jpg is a photo of it, for dragging into the Mac in a pinch.
- First a quick screen-recorded draft of the demo, to check the rhythm. Then the rendered version.

## Crisp pictures: render the real app big, do not rebuild it

Zooming three times into a Retina screenshot leaves about 360 source pixels across the frame.
That is soft. Rebuilding the screens in HTML would be sharp, but it is a second copy of the app
that drifts from the real one.

The app already draws views off screen (`--demo --render-editor`, in Sources/Matterbee/IntroShot.swift):
a real SwiftUI view in a borderless window, cached into a bitmap. That bitmap is at 2x only
because the window's backing scale is 2x. The same view can be drawn at 6x: `ImageRenderer` with
`scale = 6`, or a bitmap with a 6x transform. Text, lines and the bee are vectors until the very
last step, so a 6x picture of the care card is as sharp as print.

So the production plan becomes:

1. **`--demo --render <scene> --scale 6 <folder>`**, a small extension of DesignRender: it
   draws one named view of the demo — the care card, the Get new mail panel in each of its
   states, two task rows before and after the tick, the source card, the date row and its chip,
   the assistant with the care question and its answer, the side column — and writes a PNG each.
   Where a scene needs two states (the name swap, the tick, the chip), it writes both.
2. **One HTML page per scene**, 1080 × 1920, that places those PNGs and moves between states
   with CSS: a slow zoom, a cross-fade from state A to B, the caption on top. Live typing in the
   assistant's field is the one thing drawn in HTML, in the same font over the rendered empty field.
3. **Render to MP4**: a headless browser steps the page frame by frame at 30 fps, ffmpeg joins
   the frames and the music track.
4. **Screen recordings only** for the Calendar app in scene 12 and the iPhone camera in scene 8. The other iPhone scenes come from the simulator, rendered the same way the Mac views are.

The upside: a changed design means re-running one script. The pictures are the app, not a drawing of it.

## The draft (1 October 2026)

docs/film/draft-mac.mp4 · 101 seconds · 1080 × 1920. All Mac scenes recorded from the demo with
scripts/film/record-mac.sh and cut with scripts/film/assemble.py (see scripts/film/README.md).
Grey cards stand in for what is not recorded yet: the disguise (4), the iPhone half of 7, the scan
(8) and the share sheet (9). No music yet.

Seen in the draft, to fix in the next cut:

- Scene 11 opens the sources chip under an answer. The task row's "from the mail of …" opens the
  mail in Mail, which the demo cannot. The better source moment is the history's mail entry with
  its quote, or a rendered card.
- Scene 12 shows the dates list only: the demo build has no Calendar access, so there is no
  "Add to Calendar" chip and no Calendar half.
- Scene 7 on the Mac: the status card changes from the next step to "Soon · Physio" once the
  overdue task is ticked. Worth checking whether that is right, or whether the next step should stay.
- The captions sit over content in the tall crops; the final film gets its own caption band.

## The quick draft: screen recordings of the demo

The draft checks the rhythm, not the sharpness. You record, I cut it to portrait with the captions.

**On the Mac:** the demo's Get new mail round came to the Mac on 1 October 2026 and is not in
the released app yet, so start the Release build from the repo, on a demo store of its own (the
owner's matters stay untouched):

```bash
open -n -a .build-app/shots/Build/Products/Release/Matterbee.app --args --store /tmp/film-demo/matters.store --demo
```

Make the window about 1200 points wide and record it with QuickTime (File → New Screen Recording,
or ⌘⇧5). Leave two seconds of rest after each step.

1. Rest on the overview, the care card in view. (scene 2)
2. Click Get new mail. Wait for the list and the cost line. Rest. (3)
3. Click Sort in. Wait for the result line. (5)
4. Open Care for Mum. Rest on the next step and the summary. (6)
5. Scroll to the tasks. Tick "Collect the bath seat prescription at Dr. Brandt's". (7, the Mac half)
6. Tick "Read the Sunrise contract together with Nina". Rest while "Sign …" lights up. (10)
7. Hover and open the source of "Sign the Sunrise contract …". Rest. Close it. (11)
8. Click Add to Calendar on the assessment visit. Open Calendar, move the event to 10:30, come back. (12)
9. Rest on the files and the people. (13)
10. Ask "What do I need to do before Tuesday's visit?". Wait for the answer, click Take in on the card. (14)
11. Back to the overview. Rest. (15)

**On the iPhone** (Settings → Control Centre → Screen Recording; the demo from the Welcome screen):

1. Open Care for Mum. Tick "Collect the bath seat prescription at Dr. Brandt's". Rest. (7)
2. ⋯ → Scan. Scan the printed letter (docs/film/healthbridge-letter.png). Sort in. Take the card in. (8)
3. In Mail, open any mail, Share → Matterbee, Sort in. (9)
4. Rest on the overview. (15)

The iPhone camera itself (scene 8) is best filmed with a second phone or a camera, over the
shoulder, so the paper and the phone are both in the picture. A screen recording alone is fine for the draft.

I take the recordings, cut them into the scenes, crop each to portrait around the thing it is
about, put the caption under it, and join them with the bee at the start and the close at the
end. That is a 100-second draft we can watch the same day.

## Voice-over script

One line per scene, in the captions' words, a little fuller. Calm, unhurried, one voice.
About 190 words, which reads in 80 to 85 seconds and leaves the bee its silences.

1. Every matter, in its place.
2. Mum's care: the doctor, the insurer, the care service, your sister. One matter, one card: what comes next, what is overdue, who you are waiting for.
3. New mail is fetched and listed. Nothing is sent until you click Sort in, and you see what it would cost first.
4. Before anything leaves your Mac, the names are replaced. The AI never sees who Helga is. If the disguise can't be built, nothing is sent.
5. Sorted into the matter it belongs to. Every answer shows what it cost.
6. One thing to do now, and why it can't wait. And where things stand, in a few lines.
7. Out and about, tick it on your phone. The Mac at home knows. Your matters sync through your own iCloud, and nothing else.
8. A letter on Mum's table? Scan it, and it goes into the matter. The paper stays on your phone.
9. A mail on the way home: share it to Matterbee. It finds the matter it belongs to.
10. Tasks are yours, shared, or someone else's you're waiting for. Some can only start after another.
11. Each task and date links back to the mail it came from. Check anything in one click.
12. Add a date to Calendar with one click. Change it in either place, and the other follows.
13. Files, shared documents and everyone involved, each with their role.
14. Ask in your own words. The answer comes with its sources, and a good suggestion becomes a task in one click.
15. By evening, the card is calmer. The next step is always clear, on the Mac and on your iPhone.
16. Matterbee. Free and open source.
