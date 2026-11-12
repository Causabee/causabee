# F006 · The top-up in the bar — Why

## The problem

The owner: "the top up needs another color in used bar, to see how it travels to the next months." Today the bar is one yellow line: this month's Pro and the top-ups together. A top-up shows only as small print under it ("33 % of it from top-ups"), so the owner cannot see what is the month's, what is the top-up's, and that a top-up does not end with the month.

## Who has it

The owner, with Pro and a top-up bought, 12 November 2026: in Settings and the plan sheet, on the Mac, the iPhone and the iPad (`ProBar`, `Sources/Causabee/BeeServer.swift`).

## What we know

- The bar shows what is left of both together, since 8 November: after a top-up it said "0 % left", the top-up only in small print.
- The beeserver never ends a top-up: what is left is every top-up bought minus what top-ups paid, in any month (`server/beeserver/src/index.ts`, `extraLeft`). The month's Pro starts anew on its day; a top-up left goes on.
- The month is spent first, then the top-ups.
- The app is told shares, never money: `monthUsed`, `extraShare` (in Pro months), `renewsOn`.
- Without Pro, top-ups alone have their own bar, "Your top-ups".

## The goal

The owner sees at a glance what is left of this month's Pro and what is left of top-ups, each in a bar of its own, and that a top-up carries on into the next month.

The owner's choice, 12 November, of three ways (a darker part on the yellow bar, a second bar, one bar of two colours): "a second bar under the months bar … i think to add a second bar when top up is used is the most clear solution".

- The month's bar stays as it is, yellow.
- A second bar under it, for the top-ups, in a colour of its own: there while a top-up is left, gone when none is.
- It stays full while the month's Pro lasts, and goes down only once the month is used, as the beeserver spends them.
- On the first day of a new month, the month's bar is full again; the top-up's bar is where it was.
- More than one top-up adds up: a Pro month is $4.50 of AI, a top-up $1.50, so one is a third of a Pro month, two are two thirds (the owner, 12 November: "and when i top up two times the percentage changes"). How the bar shows that — the same length scale as the month's bar, or full at what was bought — is decided in the What.
- With top-ups and no Pro subscription, only the top-up's bar, in the top-up's colour: there is no month's Pro to show (the owner, 12 November: "when i dont use the monthly subscription only pro top up i would only see the top up bar?").

## Not in this feature

- Money in the app: the bar stays in shares.
- A history of past months.
- Any change to how the beeserver counts, spends or ends a top-up.
- The plan sheet's offers and prices.

## How we know it worked

With a top-up left, two bars on every device; on the first day of the next month, the month's bar is full again and the top-up's bar is where it was.

## Principles it touches

- **The bee takes the mental load:** two bars, each saying one thing, instead of a sum and a share in small print.
- **Said as it is (principle 11):** what is left, the month's and the top-up's, as the beeserver counts it — never money.
