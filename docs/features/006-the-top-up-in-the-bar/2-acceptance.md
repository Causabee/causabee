# F006 · The top-up in the bar — What must be true

Where the bar is: the plan in Settings (Mac, iPhone, iPad) and in the setup assistant, `PlanSettings` and `ProBar`. What it is told by the beeserver: shares, never money — `monthUsed`, `extraShare` (in Pro months), `renewsOn`, `kind`.

## Criteria

### AC-1 · Two bars: the month's and the top-ups'

- Given Pro bought, and a top-up left
- When the owner looks at the plan
- Then they see the month's bar as today, yellow, with what is left of **this month alone**: "40 % left"
- And under it a second bar in the top-ups' own colour, with what is left of the top-ups: "Top-ups · 67 % of a Pro month"
- Holds for: Mac, iPhone, iPad; with Pro and a top-up. Sources: none — the bar is about Pro, not what comes in

### AC-2 · The month is used first

- Given Pro bought, a top-up left, and the month not used up
- When the bee uses Pro
- Then the month's bar goes down and the top-ups' bar stays where it is
- And once the month is used up, the top-ups' bar goes down, as the beeserver spends them
- Holds for: Mac, iPhone, iPad; with Pro and a top-up

### AC-3 · A top-up carries over to the next month

- Given a top-up left on the month's last day
- When the month starts anew
- Then the month's bar is full again, and the top-ups' bar is where it was
- And the line under the bars says it: "Starts anew on 1 December · top-ups carry over"
- Holds for: Mac, iPhone, iPad; with Pro and a top-up

### AC-4 · Top-ups add up, on the month's scale

- Given one top-up left — a third of a Pro month
- When the owner buys a second
- Then the top-ups' bar is two thirds as long as a full month's bar, and says "67 % of a Pro month"
- And at more than a Pro month of top-ups the bar is full and the number says it: "133 % of a Pro month"
- Holds for: Mac, iPhone, iPad; with Pro or without

### AC-5 · Top-ups alone, without Pro

- Given top-ups left and no Pro subscription
- When the owner looks at the plan
- Then they see only the top-ups' bar, in the top-ups' colour, on the same scale: "Your top-ups · 33 % of a Pro month left"
- Holds for: Mac, iPhone, iPad; without Pro

### AC-6 · No top-up left, no second bar

- Given Pro bought and no top-up left — none bought, or all used
- When the owner looks at the plan
- Then they see the month's bar alone, as today, and its notes as today ("Used for this month …")
- Holds for: Mac, iPhone, iPad; with Pro

### AC-7 · Running low, as today

- Given what is left, the month's and the top-ups' together, is a fifth of a Pro month or less
- When the owner looks at the plan
- Then the bar now being used and its number are in the warning colour, as the one bar is today; the other keeps its own
- Holds for: Mac, iPhone, iPad; with Pro or without

### AC-8 · Read aloud, each bar on its own

- Given the plan with one or two bars
- When VoiceOver reads it
- Then it reads each bar apart: "This month's Pro: 40 percent left", "Top-ups: 67 percent of a Pro month left"
- Holds for: Mac, iPhone, iPad

## Must not change

- How the beeserver counts, spends and keeps top-ups: the month first, top-ups after, a top-up never ends — the server's tests, `ledger.test.ts` among them (38 pass today).
- Pro is on with a top-up and no subscription — `ProOnTests`.
- The plan in Settings shows shares, never money; the offers, the prices and the top-up's button stay as they are. No test guards the bar today: F006 adds them.
- The plan sheet's pictures for the website (`PlanShot`) still show a bar: the screen tests on the three devices.

## Open questions

None. The top-ups' bar is on the month's scale — a full bar is one Pro month (the owner, 12 November: "A").
