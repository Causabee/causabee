# The film's motion — how each beat comes to life

The language of motion, once, then each beat. Times are seconds from the start of the beat's
spoken line (the voice starts 0.5 s into a beat; "−0.3" means just before the first word).

## The language

- **One stage.** White page, no chrome. The headline sits in the top third, the object in the
  middle. Between beats the stage never cuts: the old object leaves, the new one arrives.
- **Headlines** fade in and rise 24 px over 0.5 s, ease-out, landing on the first spoken word.
  They fade out 0.3 s before the next beat's headline arrives.
- **Objects arrive** the way they do in the app: a card rises 32 px and fades in over 0.55 s,
  ease-out (cubic-bezier 0.2, 0.7, 0.2, 1). Rows arrive one after another, 90 ms apart.
  Objects leave downwards and fade, 0.35 s, ease-in.
- **A tap** is a 44 px ring that blooms from the touch point to 80 px and fades, 0.4 s, honey at
  40 %. The button under it darkens for 120 ms. Nothing else ever "clicks".
- **The bee** is the icon's bee (iOS/BeeLoader): stripes light up top to bottom, wings beat,
  the whole bee hovers. One cycle is 2.4 s, as in the app. The bee appears only while Matterbee
  works, and only beside the words that say what it does.
- **State changes** morph in place: a chip's words crossfade and its width eases, 0.3 s; a pill
  flips with a 90° turn on the x axis, 0.35 s; a checkbox's tick is drawn as a stroke, 0.25 s,
  then the row fades to its done look.
- **Highlighted words** are drawn: a honey pill grows from the left edge of the words to their
  right edge, 0.45 s, ease-out.
- **Depth, lightly.** Objects carry the app's soft shadow (0 8 24, 8 %). Context sits behind
  the object at 40 % opacity and slightly smaller (scale 0.96), so the eye knows where it is
  without reading it.
- **Nothing decorative moves.** No parallax, no particles, no camera drift except where the
  beat says so.

## The beats

**1 · Mum had a fall.** (3.0 s)
Detail: the mail line gets its unread dot and a time, "Aug 20, 09:12", as in Mail.
Motion: −0.3 the headline. 0.0 the mail line rises in. 1.2 the unread dot pulses once. Hold.

**2 · All in mail.** (7.4 s)
Detail: five mail lines, each with its sender's initial in a grey circle and its date; the
first is the line from beat 1, already there.
Motion: on "a doctor" the second line drops in under the first; "an insurer" the third;
"a care service" the fourth; "your sister" the fifth: each 0.4 s, rising 24 px, 90 ms apart
from the word. On "All in mail." the five lines jitter apart 6 px, as a pile does, and settle.

**3 · One place.** (3.5 s)
Detail: the card is the iPhone's matter card with its yellow label "3 for you · 1 together ·
waiting for 2"; behind it, at 40 %, the overview's two neighbouring cards, cropped top and
bottom, so it reads as a list.
Motion: 0.0 the five mail lines slide together into the centre and shrink into the card's
footprint (0.6 s, ease-in-out); at 0.5 the card fades in over them, its label last (0.2 s).
The neighbours fade in behind at 0.8.

**4 · One button.** (3.5 s)
Detail: the button "Get new mail" with its arrow, in the iPhone's panel at the foot of the
overview; the panel's top edge shows a sliver of the last card above it.
Motion: on "New mail?" the panel rises in. On "One button." a tap ring on the button. 0.15 s
later the button crossfades to "Fetching mail …" with the bee beside it and Cancel beneath
(the app's Reading state). The bee beats until the next beat takes over.

**5 · Until you say so.** (8.1 s)
Detail: the panel in its Ready state: "2 new mails", the two subjects, the buttons Cancel and
Sort in. Sort in is the filled ink button.
Motion: on "It reads your new mail first" the bee stops, "2 new mails" crossfades in. On
"shows you what came in" the first subject rises in, then the second, 90 ms apart. On
"Nothing goes to the AI" Cancel and Sort in rise in together. On "until you say so" the Sort
in button gets a slow single pulse of its shadow (0.8 s) and nothing is tapped. Hold.

**6 · The names are gone.** (5.0 s)
Detail: the sentence in two lines with the small labels "On your Mac" and "What the AI sees";
the two names in ink, medium weight.
Motion: on "before anything leaves your Mac" the top sentence is there; on "the names" each
name dims to grey and its letters blur (0.3 s); on "are gone" the bottom sentence appears
with "[Person A]" and "[Person B]" in gold, each landing with a 0.2 s settle. The honey
pill under them is not drawn here: the gold is enough.

**7 · Sorted in.** (2.4 s)
Detail: the line "2 mails sorted into Care for Mum · 1 new task" with its tick; under it, at
40 %, the task it brought: "Collect the bath seat prescription at Dr. Brandt's".
Motion: the tick is drawn as a stroke (0.25 s) on "Sorted"; the line fades in on "in".
The task line rises in at 1.2.

**8 · One next step.** (5.4 s)
Detail: the next-step card with its yellow label "NEXT · FROM MATTERBEE", the step, the
reason, the three buttons; under the card, at 40 %, the top of the summary box.
Motion: on "Every matter" the card rises in without its reason; on "one next step" the step
text brightens from grey to ink (0.3 s); on "and the reason" the reason unfolds under it
(height eases, 0.4 s); on "can't wait" the yellow label blinks once, 0.2 s.

**9 · Whose it is.** (3.4 s)
Detail: one task row with its owner pill in the meta line. Not three rows: one row that
changes.
Motion: the row is there from −0.3. On "whose" the pill flips from "Mine" to "Ours"; on
"it is" to "Waiting for Nina". Each flip 0.35 s with the 90° turn. The rest of the row holds.

**10 · Only after another.** (3.7 s)
Detail: two rows: "Read the Sunrise contract together with Nina" above, and under it, dimmed,
"Sign the Sunrise contract and send it back" with "only after: Read the contract …". Not four
rows: two that change.
Motion: on "Some can only start" a tap ring on the first checkbox, the tick is drawn, the
row fades to its done look and shrinks to one line (0.4 s); on "after another" the second row
brightens to ink, its "only after" line crossfades to "its turn now" (0.3 s), and the whole row
lifts 8 px and settles.

**11 · Where it came from.** (4.0 s)
Detail: the task row from beat 10 at the top, small; under it the source card as the app
shows it: sender, date, the quoted sentence with the words marked.
Motion: on "every task shows" a tap ring on "from the mail of Sep 24" in the row's meta line;
the source card unfolds beneath (0.45 s); on "the mail it came from" the honey pill is drawn
left to right under "back by 2 October".

**12 · In step with Calendar.** (5.0 s)
Detail: one date row, "Oct 6 · 10:00 · Assessment visit (medical service) · Mum's flat",
with the chip "Add to Calendar". Beside it, later, a slice of the iPhone Calendar app: the day
column with the event block. One row that changes, not two.
Motion: on "Dates go to Calendar" the row is there; on "one click" a tap ring on the chip, the
chip morphs to "in Calendar · Oct 6, 10:00" (0.3 s); on "and stay in step" the Calendar slice
slides in from the right at 60 % width, its event block at 10:00; the block is dragged down to
10:30 (0.5 s) and, in the same breath, the row's time crossfades from 10:00 to 10:30.

**13 · Ask anything.** (4.0 s)
Detail: the composer at the foot (the real one, with the paperclip and the yellow send button)
and, above it, the question bubble. The composer is the field the question is typed into.
Motion: on "Ask anything" the composer rises in with a blinking caret and the question types
itself at 18 characters per second (the field's border honey while typing); on "about the
matter" a tap ring on the send button, the text lifts out of the field into the yellow bubble
above (0.45 s), the field empties.

**14 · With its sources.** (4.0 s)
Detail: the working line "Matterbee is on it …" with the bee, then the three answer lines of
the app; the first and third at 40 %, the middle one in ink with its "Sources · 1 ›".
Motion: −0.3 the bee works. On "The answer" the bee fades and the three lines rise in, 90 ms
apart; on "comes with its sources" the middle line's "Sources · 1 ›" gets a tap ring and
unfolds into the small chip "Move Tuesday's physio …" (0.35 s).

**15 · One click.** (5.0 s)
Detail: the suggestion card as the app's action card, its title "New task? · Waiting for ·
by Oct 5", the task in its field, the reason, "Sources · 1", the buttons Dismiss and Take in.
Motion: on "A good suggestion" the card rises in; on "becomes a task" a tap ring on Take in;
the card's chrome fades, its height eases down (0.4 s) and what remains is the taken card:
the tick, the task, "Task added · Waiting for · by Oct 5", Undo; on "in one click" the tick is
drawn.

**16 · Mac and iPhone.** (7.1 s)
Detail: a Mac window outline with the matter card, and an iPhone outline with the same card;
both outlines in the thin grey line, no bezels, no shadows. Between them, later, a small
cloud-with-lock glyph.
Motion: on "On your Mac" the Mac window rises in at the top left; on "On your iPhone" the
iPhone rises in at the bottom right; on "Synced through your own iCloud" the card's yellow
label on the Mac pulses and, 0.3 s later, the same label on the iPhone pulses, with a thin
honey line travelling between them (0.5 s); on "and nowhere else" the lock glyph appears on
the line and the line fades.

**17 · Only a disguise.** (6.7 s)
Detail: the disguised sentence from beat 6, alone, with its label "What the AI sees"; above
it, small and at 40 %, the Mac window from beat 16 with a padlock on its title bar.
Motion: on "Your mail stays on your Mac" the small Mac window is there, the padlock closes
(a 0.2 s drop of its shackle); on "The AI only ever sees" the sentence rises in; on "a
disguise" "[Person A]" and "[Person B]" settle into gold.

**18 · Matterbee.** (5.1 s)
Detail: the icon, the name in the serif, the line under it.
Motion: −0.3 the icon fades in, still; on "Matterbee" the six stripes drop in from the top one
after another (0.9 s, the website's icon animation), the wings beat twice; on "Every matter,
in its place." the name and the line fade in under it. The bee settles. Hold two seconds, then
fade to white.

## What this needs

- **From Figma**: every object as its own layer, and every state the motion names as its own
  variant: the chip before and after, the pill's three words, the row open and done, the card
  and the taken card, the composer empty and typing. The section "Film · 90 s" holds the beats;
  each gets a second frame for its end state where the motion needs one.
- **The build**: one HTML page per beat, the layers as exported PNGs or as the live components
  redrawn in CSS, the motion as CSS animations timed to the voice (docs/film/timing.json gives
  each line's start). A headless browser steps the page at 30 fps and ffmpeg joins the frames
  with the voice. The website already animates this way (the hero's fetch and sort, the ask).
- **Sound**: very quiet, under the bee only, as decided; and a single soft tick with each tap.
