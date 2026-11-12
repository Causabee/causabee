# F007 · Plan and usage, the same on every device — Why

## The problem

The owner, 12 November 2026: "Pro on and off … this is actually what you're not doing … You do smart on and off. And pro is actually the subscription. On top up is also the subscription. And pro is a decision you make as a user." Today the switch is called "Pro on", so turning it off reads as giving up Pro; the Mac's plan said "Free" beside a switch saying "Pro on"; Pro bought in the simulator showed no bar at all. And the plan card opens Settings and "the whole setting view is pushed far out of the view port".

## Who has it

The owner, on the Mac, the iPhone and the iPad, with Pro bought in TestFlight that ended on 7 November and top-ups left — and everyone after the App Store release, where "I can buy on the Mac, I can buy on the phone, I can buy on the iPad. So no distinction in the future anymore."

## What we know

- What you have and whether you use it are two things: Pro or top-ups are bought (`Store.plan`, `BeeServer.extraShare`); the switch is `AutoMode` ("mail.auto"), on only with Pro or a top-up (`Plan.proIsOn`).
- The plan card is the first section of Settings on every device (`PlanSettings`), with up to two bars since F006, a line, a button and notes.
- Without the beeserver set up — a new device, the simulator — the card draws no bar (`PlanSettings.showsMeter`).
- Buying a top-up turns the switch on by itself (`Store.buy`).
- The Mac buys nothing today: it is downloaded from the website and takes the plan from the iPhone through iCloud, counted 7 days past its end (`Store.plan`, `Store.share`). The App Store release changes that; the Mac in the App Store is its own piece of work.
- The cases are drawn in `wireframes.html` here (published as "Pro and Its Switch"): where it lives, A to H, and buying.

## The goal

On every device the owner sees what they have in one row of Settings, opens a page that says it plainly with its bars, and decides whether to use Pro with a switch that never takes away what they have.

## Not in this feature

- Putting the Mac in the App Store, or buying on the Mac: its own piece of work.
- Prices, plans and what each holds.
- How the beeserver counts, spends or ends Pro and top-ups.
- The iPhone saying Pro 7 days after it ended (parked, the fix lane).
- The rest of Settings beyond moving the plan out of its top.

## How we know it worked

On the Mac, the iPhone and the iPad, Settings opens with its own sections in view and one "Plan and usage" row; the page shows every case of the wireframes as drawn; turning the switch off leaves the bars, greyed.

## Principles it touches

- **The bee takes the mental load:** what you have and what is in use, each said once, in its place.
- **Said as it is (principle 11):** the switch says what it does — whether Pro is used — and the plan says what is bought.
