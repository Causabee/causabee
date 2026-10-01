# Matterbee in 90 seconds — the script

A narrator speaks. The screen shows one thing at a time: one object from the product, drawn big
on a white page, nothing around it. No window, no sidebar, no screenshot. When the narrator moves
on, the object goes and the next one comes. The bee appears only while Matterbee works.

How to read this: **Say** is the narrator's line, word for word. **Show** is the one object on
screen. **Move** is the only thing that moves while the line is spoken. Seconds are a guide; the
voice sets the pace, and the picture waits for the voice.

Drawing rules: the app's own look — ink on white, the honey yellow for what is live, Source Serif
for a matter's name, the system font for the rest. Every object as large as the frame allows, with
its real words from the app. Portrait, 1080 × 1920.

---

**1 · 3 s**
Say: Mum had a fall.
Show: one mail line — "After your mother's hospital stay: what she needs" · Dr. Brandt.
Move: it fades in.

**2 · 5 s**
Say: Now there's a doctor, an insurer, a care service, and your sister. All in mail.
Show: four more lines stack under the first — "Application received: care level for Helga Voss" · Healthbridge Care Fund; "Offer: Sunrise Home Care visits for Helga" · Yusuf Kaya; "Who does what this week?" · Nina Voss; "Prescription for the bath seat is ready" · Dr. Brandt.
Move: one line per beat of the voice.

**3 · 3 s**
Say: Matterbee puts them in one place.
Show: the five lines slide together into one card: "Care for Mum (Helga) after her fall".
Move: the slide, then the card holds.

**4 · 3 s**
Say: New mail? One button.
Show: the button "Get new mail".
Move: a click; the bee appears beside it, stripes sorting, wings beating.

**5 · 7 s**
Say: It reads your new mail first, and tells you what sorting it in would cost. Nothing goes to the AI until you say so.
Show: "2 new mails" — "Prescription for the bath seat is ready", "Re: Who does what this week?" — then the line "Sorting in costs about $0.02." — then the button "Sort in".
Move: the lines come one by one; "Sort in" comes last and waits.

**6 · 5 s**
Say: And before anything leaves your Mac, the names are gone.
Show: one sentence, large: "Dr. Brandt has the bath seat prescription for Helga."
Move: "Dr. Brandt" becomes "[Person A]", "Helga" becomes "[Person B]". Nothing else moves.

**7 · 2 s**
Say: Sorted in.
Show: the line "2 mails sorted into Care for Mum · 1 new task · $0.012" with the tick mark.
Move: the tick draws itself.

**8 · 5 s**
Say: Every matter has one next step, and the reason it can't wait.
Show: the next-step card: "Read and sign the Sunrise contract" and under it "It has to be back by 2 October for the first visit on 7 October."
Move: the title first, the reason a beat later.

**9 · 4 s**
Say: Every task says whose it is.
Show: one task row: "Sign the Sunrise contract and send it back", with the pill "Yours".
Move: the pill flips to "Shared", then to "Waiting for", then back to "Yours".

**10 · 4 s**
Say: Some can only start after another.
Show: two rows. "Read the Sunrise contract together with Nina" above, and under it, grey, "Sign the Sunrise contract and send it back · only after the one above".
Move: a tick on the first row; the second turns from grey to ink: "its turn now".

**11 · 4 s**
Say: And every task shows the mail it came from.
Show: the quote: "… if the signed contract is back by 2 October." · from the mail of Sep 24 · Yusuf Kaya.
Move: "back by 2 October" is marked in yellow, left to right.

**12 · 4 s**
Say: Dates go to Calendar in one click, and stay in step.
Show: one date row: "Assessment visit · Tue 6 Oct · 10:00 · Mum's flat", with the chip "Add to Calendar".
Move: a click; the chip becomes "In Calendar" with the calendar mark.

**13 · 4 s**
Say: Ask anything about the matter.
Show: the assistant's field, gold while typing.
Move: the question types itself: "What do I need to do before Tuesday's visit?"

**14 · 4 s**
Say: The answer comes with its sources.
Show: one answer line: "Move the physio that day to the afternoon: the visit starts at 10:00." with the small source mark "T2" at its end.
Move: the line appears, then the mark.

**15 · 5 s**
Say: A good suggestion becomes a task in one click.
Show: the suggestion card: "Ask a neighbour to be at Mum's flat by 09:45 on 6 October" with the button "Take in".
Move: a click; the card becomes the line "Task added · Waiting for · by Oct 5".

**16 · 5 s**
Say: On your Mac. On your iPhone. Synced through your own iCloud, and nowhere else.
Show: the care card from beat 3, small, inside a Mac window outline; then the same card inside an iPhone outline beside it.
Move: the phone slides in; the card is the same on both.

**17 · 4 s**
Say: Your mail stays on your Mac. The AI only ever sees a disguise.
Show: the sentence from beat 6, already disguised: "[Person A] has the bath seat prescription for [Person B]."
Move: nothing. The line holds.

**18 · 4 s**
Say: Matterbee. Every matter, in its place.
Show: the icon, the bee on its yellow, and the name under it.
Move: the stripes drop in once, the wings beat twice, the bee settles.

---

Spoken words: 155. At a calm pace that is 75 to 80 seconds of voice, and the rest is silence
where the picture does its work. Total: about 90 seconds.

## What we draw

Eighteen beats, fourteen objects, each one frame in Figma (the file's Mac and iPhone parts hold
the real components to draw them from):

1. a mail line (sender, subject) — beats 1, 2
2. the matter card — beats 3, 16
3. the button "Get new mail" — beat 4
4. the bee at work — beats 4, 5, 13
5. the new-mail list with the cost line and "Sort in" — beat 5
6. a sentence with two names, and its disguise — beats 6, 17
7. the sorted-in line with the tick — beat 7
8. the next-step card — beat 8
9. a task row with its pill — beats 9, 10
10. a quote from a mail with the marked words — beat 11
11. a date row with the Calendar chip — beat 12
12. the assistant's field — beat 13
13. an answer line with a source mark — beat 14
14. the suggestion card and the "Task added" line — beat 15
15. a Mac window outline and an iPhone outline — beat 16
16. the icon — beat 18

Each frame gets its states (the pill's three words, the chip before and after, the card before and
after "Take in"), and the film moves between states. Nothing else moves.

## The voice

One voice, calm, unhurried, no sell. Short sentences, a breath between beats. The narrator never
says "click here" or names a button; the picture shows the button, the voice says what it does.
For ElevenLabs: the eighteen "Say" lines in order, as one text, with a line break between beats.
