# UI check · F005, the chat in two depths · 2026-11-11

Scope: branch `feature/005-the-chat-in-two-depths` against main — `Sources/Causabee/AskSteps.swift`, `Sources/Causabee/Conversation.swift`, `Sources/CausabeePhone/AssistantSheet.swift` · rules: docs/design-system.md

| Question | Verdict |
|---|---|
| Apple's HIG | pass |
| Causabee's tokens | pass |
| Reuses the components | pass |
| Built on Liquid Glass | pass |

## What was read

- **`AskSteps`** (Mac, iPhone, iPad — one view for both apps): one new case of its words, "Looking in the whole matter …", and its seconds counted on while it looks deeper. The same `BeeLoader`, `.caption`, `.secondary` as its three other lines (T4); Dynamic Type through the text style (H4); VoiceOver reads the line as one element, as before (H6); no new control, so no target (H2). The preview "Steps of asking" shows all four lines.
- **The chat's footer**, Mac `Conversation` and iPhone/iPad `AssistantSheet`: the model's name now comes from `AIJob.chatSentTo`. While every chat question goes to Sol it says exactly what it said before; the same words on both apps (C4).
- **The depth's code** in `Conversation.send` and `AssistantSheet`: not a view; nothing drawn.
- No new view, modifier or style (C3); no glass added or changed (G1–G5).

## Findings

None.

## Kept on purpose

None.

## Mechanical check

On the branch's changed lines:

```
0 ✗ · 0 ? · rules in docs/design-system.md
```

Over the three files whole, 27 ? on lines F005 did not touch — radii by number (T5), glyphs by point size (H5), two tap gestures (H1) in `AssistantSheet` — none of them changed or made worse here; not this feature's to fix.

Verdict: pass
