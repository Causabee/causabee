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
- A guess, not known: that fewer, calmer pictures and one first step bring a first matter sooner. Nobody but the owner has tried the first start.

## The goal

A new person sees in a few calm pictures what a matter can be, then starts their first one at once — by typing what is on their mind or adding what they have.

## Not in this feature

- Mail's setup itself: its steps stay as they are; only when it is offered changes.
- The demo's matters and what they hold.
- The App Store's own page and its screenshots.
- The website.
- The plans and Pro: what they cost, how they are bought.
- Help's other pages, and the Settings.
- How the bee reads what is added, or what the first matter's page shows.
- A tour, tips or hints on the pages after the welcome.

## How we know it worked

Someone the owner gives Causabee to, opening it for the first time, has their first matter within two minutes, without asking how.

## Principles it touches

- **1 · Every source counts the same:** the first step takes typing, a screenshot, a photo, a file or a note alike; mail is not the way in.
- **9 · Less, not more:** fewer, calmer pictures; nothing asked before it is needed.
- **10 · Clear words:** one short promise, short lines under each picture.
- **11 · Private:** said once, in one line, before anything is added.
- **12 · Everywhere the same:** the same welcome on the iPhone, the iPad and the Mac.
- A new rule is likely: *Ask for nothing before it is needed* — mail, iCloud and Pro are offered when they help, not at the door. Named here; it goes into the manifesto at stage 5 if the owner agrees.
