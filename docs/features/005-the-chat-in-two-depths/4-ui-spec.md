# F005 · The chat in two depths — Looks

The depth itself is never shown: no badge, no switch, no "light" or "deep" (Why: the bee carries the mental load; principle 9). What changes on screen is one line while the bee looks deeper, and — only if Terra passes the test — which model the chat names.

## Screens and states

**The chat's thread, the turn being asked** — on the Mac (`AssistantView`, the line drawn by `AskSteps`), on the iPhone and iPad (`AssistantSheet`, the same `AskSteps`).

| State | What the line says |
|---|---|
| A quick question, light | As today: "Disguising names …", then "Thinking … · 4 s", then "Putting names back …" |
| A question that goes deep at once | As today, the same three |
| A light answer that lacks something, going deeper | After "Thinking … · n s": **"Looking in the whole matter … · n s"** — the seconds go on from when the question first went out, they do not start again. Then "Putting names back …". The light answer is never shown. |
| The deeper ask fails | The error as today, in its place. Nothing of the light answer. |
| Stopped while looking deeper | "Stopped." as today. |
| The answer | As today: its lines, its cards, and under it the model that answered. |
| Without Pro and without an own key | As today: no change. |

Empty, one item, many, long text: not needed — the line is one sentence of fixed words, and the thread around it does not change.

**The chat's footer, under the field** (Mac `Conversation`, iPhone and iPad `AssistantSheet`): as today while every chat question goes to Sol. Only if Terra passes the test and takes the light questions, the model part changes (below). "Sees: …" stays what the chat can reach — the whole matter — since a question that needs it gets it.

**Settings, what each model does, and causabee.app** (`AIJob.said`): as today while the chat is all on Sol. If Terra takes the light questions, the chat's sentence changes (below).

## Words

| Where | Text |
|---|---|
| The asking line, going deeper | Looking in the whole matter … |
| The footer, only if Terra takes quick questions | Always pseudonymised sent to OpenAI GPT-6.1 Sol, quick questions to OpenAI GPT-6.1 Terra |
| Settings and causabee.app, only if Terra takes quick questions | The chat with OpenAI GPT-6.1 Sol, quick questions with OpenAI GPT-6.1 Terra. |
| Under an answer | As today: the model that wrote it. A quick question answered by Terra says Terra. |

Checked against the house rules: short, few words, no jargon, no ids; no source named, so none left out. The footer's existing "goes pseudonymised, like the mails" names mail only: parked for the fix lane, not changed here.

## On each device

The same on the Mac, the iPhone and the iPad: one `AskSteps` line, the same words. The iPhone and iPad draw it at size 12, the Mac at 10, as today. No layout changes.

## Undo, and what the user can take back

Nothing new to take back: the depth changes what is sent, not what is done. The cards and their Undo are as today.

## Accessibility

- VoiceOver reads the line as one element, as today: "Looking in the whole matter …, 9 s".
- Large text: the line wraps like the other steps; nothing is cut off.
- Dark mode: secondary text, as the other steps.
- No new control, so no new tap area.

## Design system

- `AskSteps` with its `BeeLoader`, caption type, secondary colour — the parts the asking line uses today (design-system.md, components). One new case of its words, nothing else.
- The footer and Settings: their existing text styles; only words change, and only if Terra passes.
- No new part, colour or font.

## Picture

`AskSteps`'s preview "Steps of asking" gets the fourth line. Its render on the Mac and the iPhone goes into `looks/` in this folder at Build, before `/ui-check`. Today's three lines, for comparison, are what the preview shows now:

```
🐝 Disguising names …
🐝 Thinking … · 7 s
🐝 Looking in the whole matter … · 9 s     ← new
🐝 Putting names back …
```
