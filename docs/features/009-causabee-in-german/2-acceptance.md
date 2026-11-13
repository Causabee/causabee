# F009 · Causabee in German — What must be true

## Criteria

### AC-1 · The app speaks the device's language

- Given a device set to German
- When Causabee is opened anywhere — the welcome, the overview, a matter, the chat, Settings, the plans, a menu, an alert, a notification, an empty page, an error
- Then every word the app says of its own is German: nothing English is left, nothing is a key left showing (`welcome.title`), nothing is half-translated in one line
- Holds for: iPhone, iPad, Mac · Pro and without Pro · all sources

### AC-2 · A matter keeps its own language

- Given a German device with a German matter and an English matter
- When each is opened
- Then what the bee wrote about the matter — its name, the brief, the digest, the tasks and dates' words, the next step, Good to know, the chat's answers — is in that matter's own language, as today; the app's frame around it is German in both (the owner, 13 November: "the brief comes in. the lang of the conent — i can have german and english matters")
- Holds for: all sources · iPhone, iPad, Mac · Pro and without Pro

### AC-3 · Dates, times and numbers as the device writes them

- Given a German device
- When a day, a weekday, a month, a time, a duration, a share or a price is shown
- Then it reads as German does ("Freitag, 13. November", "14:30", "33 %"), never forced into English
- And what is never shown to a person — a date parsed from a mail, a day sent to a model, a key in the store — stays as it is (`en_US_POSIX`), so nothing read or written changes meaning
- Holds for: iPhone, iPad, Mac · all

### AC-4 · One German word for one thing

- Given the iPhone, the iPad and the Mac
- When the same thing is named on each — a menu item, a button, a state, a plan, the bee's own lines
- Then the German word is the same on all three, because it comes from one place; and the same English thing never has two German words in the app
- Holds for: iPhone, iPad, Mac · all

### AC-5 · German fits

- Given German, where words are longer
- When any screen is shown, at the usual text size and at the largest
- Then nothing is cut off, nothing overlaps, no button loses its words, and a line that cannot fit is rewritten shorter rather than squeezed — principle 10 holds in German too
- Holds for: iPhone, iPad, Mac · all

### AC-6 · The owner can see German on an English device

- Given the owner's own iPhone, iPad or Mac, set to English
- When they pick German for Causabee alone, in the device's own settings
- Then Causabee speaks German while everything else stays English, and back again — with no switch inside Causabee (the owner, 13 November: "decvice lang, but i need to test it on my eng device")
- Holds for: iPhone, iPad, Mac · all

### AC-7 · The App Store page in German

- Given the German App Store
- When Causabee's page is looked at
- Then its name, subtitle, description, keywords, screenshots and the beta's "What to test" are German, and the English page stays as it is for every other store
- And this feature's part is the words: written in the repository, each field inside Apple's own limit, held by a test. Causabee has no page in the German store yet — pasting them into App Store Connect, with the German screenshots, is a step of the release that makes the page, and it is written down as one (13 November)
- Holds for: the App Store · all

### AC-8 · Nothing already there is rewritten

- Given matters, notes, briefs and tasks that already exist on a device
- When the language changes, either way
- Then nothing in them changes: no word the bee wrote before is translated, nothing is read again, nothing costs AI
- Holds for: all sources · iPhone, iPad, Mac · all

### AC-9 · English stays as it is

- Given a device in English, or any language that is not German
- When the app is used
- Then every word is exactly as today, to the letter — the words' tests pass unchanged
- And where a test asserts a **formatted day** ("1 December", "Sep 30"), it says which language it is asking about, because a day now follows the device and this Mac's region is German; the words around the day do not change
- Holds for: iPhone, iPad, Mac · all

### AC-10 · German for whoever listens

- Given VoiceOver on a German device
- When a screen is read aloud
- Then what it reads is German too: labels, hints and the words said for bars, pictures and cards
- Holds for: iPhone, iPad, Mac · all

## Must not change

- **The words in English, to the letter:** `SaidAsItIsTests`, `PlanWordsTests`, `StoreCopyTests`, `OwnCopyTests`, `PlainWordsTests`, `WelcomeTests`, `ProMeterTests`.
- **Every source counts the same, and the manifesto's rules:** `ManifestoTests`.
- **What the bee is told, and what it writes about content:** `ExtractionPrompt` stays `extract-v18` and `DeviceReader` `device-2` — the prompts are English and say "write in the email's language", as today; the chat keeps `AssistantAsk.language`.
- **What is parsed or sent:** mail dates (`EMLParser`), the model's dates (`DeviceReader`), the golden set's (`GoldenSet`) stay `en_US_POSIX`.
- **What is stored:** matter keys, source ids, `UserDefaults` keys and the ledger's words are not words a person reads and do not change. The SwiftData schema: untouched.
- **The beeserver:** it says shares and codes, never words a person reads.

### AC-11 · Causabee says du

- Given any German screen
- When Causabee speaks to the person
- Then it says **du**, never Sie, and keeps it everywhere — "Was beschäftigt dich?", "deine Anliegen", "Dein Name" (the owner, 13 November, chose du over Sie and over no address at all); the bee's own voice stays as English's: short, calm, never pushing
- Holds for: iPhone, iPad, Mac · all

## Open questions

None. Decided with the owner on 13 November: the device's language with no switch of Causabee's own (AC-1, AC-6); a matter keeps its own language (AC-2); **du**, not Sie (AC-11). Claude writes the German in the house's rules — short sentences, few words, never mail-only — and the owner reads every line as a native speaker on their own device before the Build gate; nothing ships unread.
