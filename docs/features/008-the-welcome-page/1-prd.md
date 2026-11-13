# F008 · The welcome page — Why

## The problem

The first start is dense: a promise, four full pictures, then a page of what this device has — mail, iCloud, Pro — with the demo beside Start. It feels like an expert tool before anything is in it. A new person learns how Causabee works instead of starting their first matter, and mail's setup, the hardest step, stands right at the start.

## Who has it

Someone who just found Causabee in the App Store and opens it for the first time, on an iPhone, an iPad or a Mac. They have something on their mind — Mum's care after her fall, a claim, a move — and maybe a screenshot, a photo or a file about it, maybe nothing yet.

## What we know

- The owner, 12 November: "it might be overwhelming with all the information … a bit dense and feels like an expert tool. We need simplicity."
- Where they land: "ideally in Causabee" — their own, empty. "The demo is only when they are totally stuck": a second option, not the first.
- Mail: "a bit complex, but to do this in the very beginning is also not a good idea." Importing by hand (a note, an .eml) is for experts.
- The first step: typing or adding — "depends on the person. Both should work."
- Pictures: "how a matter can look like and what's all possible would be good. But when they are too full, it's also kind of creating mental load and maybe also fear." Balanced: some inspiration, "and then jump into the matter."
- Today (`Sources/Causabee/CausabeeApp.swift` the Mac's five pages, `Sources/CausabeePhone/Welcome.swift` the iPhone's and the iPad's, the same since `ec2461f`): the promise, four pictures of the demo's matters, then "Ready when you are" with what this device has, "Try the demo" and "Start".
- Growing with it: "you need to grow with the product … simple first to get started, but when you grow with it, then the features can be very useful and meaningful."
- A guess, not known: that fewer, calmer pictures and one first step bring a first matter sooner. Nobody but the owner has tried the first start.

- **The first matter must be smart (13 November).** Trying the build, the owner typed one line with a typo, "Der umzug ist für dne 1.2.2027 geplant": Apple's model on the Mac named the matter "move" and made up two dates, "die Verteilung" and "den Tag". Spelled right, the same line gave "Umzug" and 1 February. Pro's cloud model read "Muttis Reha startet am 23.11." as a note with no matter: no name, no date. The owner: "if this app should somehow become a success, we need to start with a smarter way and then also show people what's possible. Otherwise, it feels like a dumb thing and then you will never update because you're not trusting the possibilities."
- **A start credit (the owner, 13 November):** "give away one top-up pro for each new user. Everyone who launches the app gets a top-up credit … They'd start in light mode with 3 euros free. Gives them enough to set up properly and get a good first experience. Once it runs out, it falls back to on-device and we ask them to top up again. This way they see what the product can really do." And: "every user can top up for pro, light plus pro".
- Today: three plans — Causabee (free, 3 open matters), Causabee Plus (every matter, on the device), Causabee Pro (the bigger AI, up to a monthly limit). A top-up, "Pro, now and then", can already be bought on every plan: $1.50 of AI use, a third of a Pro month, sold at about €3, kept until used (`server/beeserver/src/index.ts`, `topUps`). Without Pro, a top-up alone lets Pro read (`Plan.proIsOn`, `kind: credit`).
- The beeserver already has a ledger kind `grant`, today given by hand (`/admin/grant`), counted as a top-up is. But a person who bought nothing has no account there yet: accounts begin with an Apple purchase.
- Apple gives every download a signed record, a free app's too (`AppTransaction`): one per Apple account, the same after deleting and installing again. A start credit can be tied to it, once per person, with nothing to type or sign up for.
- The cost: at most one top-up's AI, $1.50, for each new person who uses it all. Token cost is the owner's main worry; the credit is the one place Causabee pays for someone who has not paid.
- A guess, not known: that a first matter read well makes people buy Plus, Pro or a top-up more often than one read on the device.

## The goal

A new person sees in a few calm pictures what a matter can be, then starts their first one at once — by typing what is on their mind or adding what they have — and Causabee reads it with its best model, paid by a start credit given at the first start, so the first matter is right and they see what Causabee can do. When the credit is used, Causabee reads on the device again and offers a top-up, on every plan.

## Not in this feature

- Mail's setup itself: its steps stay as they are; only when it is offered changes.
- The demo's matters and what they hold.
- The App Store's own page and its screenshots.
- The website.
- The plans, Pro and the top-up themselves: what they cost, what they hold, how they are bought. The start credit is one top-up's worth, given; nothing sold changes.
- A credit for people who used Causabee before this build: only a first start gets it.
- Help's other pages, and the Settings.
- How the bee reads what comes in after the first matter; the first matter's page.
- A tour, tips or hints on the pages after the welcome.
- Showing the rest of Causabee step by step as someone grows with it — the rule is named here; where else it applies is parked, each its own feature.

## How we know it worked

Someone the owner gives Causabee to, opening it for the first time, has their first matter within two minutes, without asking how — with a sensible name and the right dates, a typo or not. In the beeserver's own count: how many new people use their start credit, and how many of them later buy Plus, Pro or a top-up.

## Principles it touches

- **1 · Every source counts the same:** the first step takes typing, a screenshot, a photo, a file or a note alike; mail is not the way in.
- **9 · Less, not more:** fewer, calmer pictures; nothing asked before it is needed.
- **10 · Clear words:** one short promise, short lines under each picture.
- **11 · Private:** said once, in one line, before anything is added. With the start credit, the first words leave the device, disguised — as with Pro.
- **Said as it is:** the credit's words say what it is, what is left and what comes after, never a countdown or pressure.
- **12 · Everywhere the same:** the same welcome on the iPhone, the iPad and the Mac.
- A new rule is likely: *Simple to start, more as you grow.* The first start asks for nothing before it is needed — mail, iCloud and Pro are offered when they help, not at the door; what Causabee can do shows when it becomes useful. Named here; it goes into the manifesto at stage 5 if the owner agrees.
