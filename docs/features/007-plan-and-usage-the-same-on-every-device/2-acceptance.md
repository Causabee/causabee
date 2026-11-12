# F007 · Plan and usage, the same on every device — What must be true

The cases are drawn in `wireframes.html` (published as "Pro and Its Switch"). The words in quotes are the proposal; Looks fixes them. Sources: none — the plan is about Pro, not what comes in.

## Criteria

### AC-1 · One row, and Settings in view

- Given any plan
- When the owner opens Settings
- Then its top is one row, "Plan and usage", with the plan's name and one line — "Causabee Pro · 59 % left · 33 % in top-ups", "Causabee · 37 % in top-ups", "Causabee · Free" — and a thin bar when there is Pro or a top-up; the sections after it are in view without scrolling
- And the row opens the plan's own page
- Holds for: iPhone, iPad; on the Mac, "Plan" is a pane of the Settings window, and the window opens on its first pane

### AC-2 · The page says what you have

- Given the plan page
- When it opens
- Then its name and corner say what is bought: "Causabee · Free", "Causabee Plus · renews 14 November", "Causabee Pro · renews 28 November", "· ends 28 November", "· payment problem", and after Pro ended with top-ups left, "Pro ended 7 November"
- Holds for: Mac, iPhone, iPad; every plan

### AC-3 · Pro or top-ups: always a bar

- Given Pro bought or a top-up left
- When the page or the row is shown before the beeserver has counted anything — a new device, the simulator
- Then there is a bar, empty, saying "not counted yet" — never none
- Holds for: Mac, iPhone, iPad; with Pro or top-ups

### AC-4 · The switch decides the use, not the plan

- Given Pro or a top-up
- When the owner turns "Use Pro" off
- Then the plan and its bars stay, greyed, saying "not in use"; Apple's model on this device reads what comes in; turned on again, nothing was lost
- Holds for: Mac, iPhone, iPad; with Pro or top-ups

### AC-5 · Nothing to use: the switch leads to the plans

- Given neither Pro nor a top-up
- When the owner turns "Use Pro" on — in Settings, on the page or on the bee
- Then the plans open, as today, and the switch stays off
- Holds for: Mac, iPhone, iPad; without Pro

### AC-6 · A top-up from the page, whatever the plan

- Given Free, Plus or Pro
- When the owner looks at the page
- Then the top-up is there to buy: "Add a top-up · price" with Pro, "Pro, now and then · price" without; filled once what is left is a fifth of a Pro month or less, as today
- Holds for: iPhone, iPad; the Mac where it can buy (not in this feature)

### AC-7 · Used up, said plainly

- Given Pro on and nothing left — the month used, no top-up
- When the owner looks at the page or the switch
- Then the switch says it waits: "nothing left to use until 28 November", and the top-up button is filled
- Holds for: Mac, iPhone, iPad; with Pro

### AC-8 · The same words wherever Pro is turned on or off

- Given the bee (held, right-clicked, the window's small bee on the Mac) and the chat's offer of Pro
- When they offer to turn it on or off
- Then they use the switch's words — "Use Pro", "Stop using Pro" — not "Turn on Pro" / "Turn off Pro"
- Holds for: Mac, iPhone, iPad

### AC-9 · A top-up bought is used

- Given the switch off
- When the owner buys a top-up
- Then "Use Pro" turns on by itself, as today: it is what was just paid for
- Holds for: iPhone, iPad; the Mac where it can buy

### AC-10 · The same on every device

- Given the same plan, top-ups and switch
- When the owner opens the row and the page on the Mac, the iPhone and the iPad
- Then each shows the same case of the wireframes, with the same words
- Holds for: Mac, iPhone, iPad

## Must not change

- The bars, their scale, their colours and numbers — `ProMeterTests` (F006).
- Pro is used only with Pro or a top-up — `ProOnTests`.
- How the beeserver counts and spends — the server's tests.
- Buying, restoring and the plans' prices and offers — no test today; the screen tests open Settings on the three devices.
- The switch's state is the same on every device, through the profile (`ModelChoiceSync`).

## Open questions

None. The owner took every recommendation, 12 November: "Take all" —

1. The switch is called "Use Pro".
2. Off, the bars stay, greyed, "not in use".
3. Top-ups without Pro: the corner says why — "Free", "Plus · renews …", "Pro ended 7 November".
4. "Use Pro" is also a row in Settings, under "Plan and usage".
5. Free with top-ups: the top-up's own button on the page.
6. A top-up bought turns "Use Pro" on, as today.
7. The Mac in the App Store comes after F007, as its own work; F007 keeps the Mac's buttons as today until then.
