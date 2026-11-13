# F009 · Causabee in German — Why

## The problem

Causabee speaks only English. Every word it says of its own — the welcome, the buttons, the plans, Settings, what a notification says — is written in English in the code, and its dates are forced into English too ("Friday, November 13"). The owner, 13 November 2026: "since I'm German, to launch the first version only in Germany. We need to be ready for the App Store and also to have a German version of the product. So this is actually a really important task before we do App Store things." A German person opening Causabee from the German App Store would find an English app around their German matters.

## Who has it

Someone in Germany who finds Causabee in the App Store, on a German iPhone, iPad or Mac. Their mail, their letters and their notes are mostly German; some are English. They want the app to speak their language — and Causabee's first release goes to that store only.

## What we know

- **Nothing is localised today.** No `.lproj`, no string catalogue, nothing: about 736 words sit in the code as English `Text`, `Label` and `Button` strings, plus the menu words in `Say` (`MatterMenus.swift`), the notifications (`CardActions.swift`), the plan's words (`PlanSheet.swift`, `ProMeter.swift`) and the welcome's (`Welcome.swift`).
- **Dates and numbers are forced into English:** 39 places set `Locale(identifier: "en_US")`, `en_GB` or `en_US_POSIX` by hand (`OverviewWeek.swift`, `Journal.swift`, `ProMeter.swift` and others). A German device would still read "Friday, November 13" and "1 December".
- **The bee already writes in the content's language.** The reading prompt says so (`ExtractionPrompt` "Write in the email's language": a German mail gets a German digest, German tasks, German dates' words), and the chat answers in the question's language (`AssistantAsk.language`). This part works and is not the problem.
- **The owner's own devices are English.** They need to see the German app without changing their Mac: iOS and macOS let a person pick one app's language once the app ships more than one, which is how it will be tried (13 November: "decvice lang, but i need to test it on my eng device").
- **The App Store page** — name, subtitle, description, keywords, screenshots and the "What to test" notes — is written once per language in App Store Connect. Today only English exists there.
- A guess, not known: that a German person would turn away from an English app. Nobody but the owner has opened Causabee yet.

## The goal

On a German device Causabee speaks German — every word of its own, its dates and its numbers — and its App Store page is German, so the first release can go to the German store. The bee's words about a matter stay in that matter's own language, so German and English matters sit side by side on one device and each reads as it came in.

## Not in this feature

- **The bee's own writing about content:** the brief, the digest, tasks, dates' words, the next step and the chat's answers keep following the matter's language, as they do today (the owner, 13 November: "the brief comes in. the lang of the conent — i can have german and english matters"). No prompt change, no new prompt version.
- **A language switch in Causabee's own Settings:** it follows the device, as Apple's apps do. The device's own per-app language is what a person uses to change it.
- **Any language but German and English.**
- **The website** (`site/`): its own piece of work, after the release.
- **Translating what is already in a matter.** Nothing already written is rewritten — matters, notes and briefs stay as they are.
- **The App Store release itself:** availability, price, review and the Mac's own listing (that is the next feature in the order).
- **The demo's made-up matters:** they stay as they are, and keep their own languages.
- **What the beeserver says.** It answers the app in shares and codes, never in words a person reads.

## How we know it worked

A German iPhone, iPad and Mac, each with Causabee from this build: every word the app says of its own is German, every date and number is German, and nothing is cut off or English. On the same device, an English matter still reads English and a German one German. The App Store page shows German in the German store.

## Principles it touches

- **10 · Clear words:** short sentences and few words must hold in German too, where words are longer; a German line that no longer fits is not a translation but a rewrite.
- **12 · Everywhere the same:** one German word for one thing, on the iPhone, the iPad and the Mac — the words come from one place, as the welcome's already do.
- **20 · A name is made of the words that came in:** a matter's name stays in its own language; the app's frame around it is the device's.
- A new rule is likely: *The app speaks your language; a matter speaks its own.* Named here; it goes into the manifesto at stage 5 if the owner agrees.
