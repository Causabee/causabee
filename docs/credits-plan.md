# Plan: Matterbee credits

People buy small packs of credits in the App Store and spend them on AI jobs. Light users pay
very little and heavy users pay more. Anyone who wants to can still use their own API key.

Written 2026-10-01. Nothing here is built yet.

## The idea in one picture

```
Today:     App ──(own API key)──────────────────────────▶ Anthropic / Mistral / OpenAI

Credits:   App ──(credit account)──▶ Matterbee server ──(owner's API key)──▶ Anthropic / Mistral / OpenAI
                                       │
                                       └─ checks balance, counts the real cost, takes off credits
```

The app sends the same request it sends today, only to a different address. The server adds
the key, passes the request on, reads the token counts from the answer, and takes off the
credits.

## Decisions

| Question | Choice | Why |
|---|---|---|
| What a credit is worth | 1 credit = $0.005 of real AI cost | Small enough that a cheap mail costs about 1 credit |
| Pack | One pack: €4.99 = 500 credits | One price is easy to explain. Add more packs later if asked |
| Free trial | 200 credits for each new account, once | About $1 of real cost per new user |
| Own API key | Stays, as a second choice in Settings | Power users and the owner keep it |
| Do credits expire? | Never | App Store rule 3.1.1 for bought credits |
| Name in the app | "credits", never "tokens" | People don't know what a token is |
| Model names | Quick (Mistral Large 3) / Careful (GPT-6.1 Sol, the default) / Best (Claude Opus 5), with the real model name shown smaller | People choose by what it does, not by brand. Sol is cheap and very good |

### What things cost in credits (from today's prices in `Claude.Model`)

| Model | Real cost per mail | Credits per mail |
|---|---|---|
| Mistral Large 3 | ≈ $0.004 | 1 |
| Mistral Medium 3.5 | ≈ $0.016 | 3 |
| GPT-6.1 Sol | ≈ $0.021 | 4 |
| Claude Opus 5 | ≈ $0.035 | 7 |
| GPT-6 Astra | ≈ $0.10 | 20 |

Example: a first import of 300 mails on Mistral Large costs about 300 credits. On Opus it costs
about 2,100.

### The money for one €4.99 pack (Germany)

| | |
|---|---|
| Price | €4.99 |
| VAT 19% (Apple pays it) | −€0.80 |
| Apple 15% (Small Business Program) | −€0.63 |
| **Paid out to the owner** | **≈ €3.56** |
| Real AI cost of 500 credits | ≈ €2.30 ($2.50) |
| **Left for the server and the trials** | **≈ €1.25** |

The aim is to cover costs, not to make a profit.

## Steps

Each step works on its own, in this order. The owner tries each one before the next starts.

### Step 1: The server, used only by the owner

The details, including direct access vs. a gateway, are in [credits-server.md](credits-server.md).

- A **Cloudflare Worker** with a small database (D1) holds the balances. The free plan is
  enough at first, and there is no machine to look after.
- Three routes, one per provider: `/anthropic`, `/mistral`, `/openai`. Each takes the same body
  the app sends today.
- Before a request: check the balance, and hold back the app's estimate.
- After the answer: read the token counts (`usage`), work out the real cost with the same
  numbers as `Claude.Model.cost(...)`, turn it into credits, and replace the hold with that.
- A ledger table: every purchase, grant, spend and refund as one row. The balance is the
  ledger's sum, so it can always be checked.
- **The server stores nothing of the request or the answer.** No logs of the body, only:
  account, model, tokens, credits, time.
- The model prices live on the server too, so the price of a credit can change without a new
  app.
- The owner gets credits by hand and uses the server for one month. **The check:** do the
  credits taken off match the providers' invoices?

### Step 2: The app can use credits

- `Claude` already sends everything through one `send(_:model:)` in
  `Sources/MatterCore/Claude.swift`. It gets a second way to send: to the server's address,
  with the account's token in place of the API key. Mistral and OpenAI go the same way.
- Settings: **"Pay with: Matterbee credits / my own API key"**. Credits is the default for new
  users.
- The balance is shown in Settings, and in the toolbar when it gets low (under 50).
- Every quote that today shows dollars (`DailyDoor.costPerMail`, the screenshot quote) shows
  credits in credits mode: *"Sorting 340 mails needs about 340 credits. You have 410. Go?"*
- No credits left: the job stops cleanly and nothing is lost. The app says "Buy credits to
  go on" and shows the Buy button.

### Step 3: Buying in the App Store

- One **consumable** product in App Store Connect: `credits.500`, €4.99. The **Paid
  Applications agreement**, bank details and tax forms have to be signed first.
- Buying uses StoreKit 2. The app sends the signed transaction to the server. The server
  checks Apple's signature and adds the credits once per transaction id. The same purchase
  never counts twice.
- **Who the account is:** StoreKit's `AppTransaction` gives an id per Apple Account and app.
  There is no sign-up and no password, and a reinstall finds the same balance.
- **Refunds:** the server listens to Apple's *App Store Server Notifications*. A refund takes
  the credits back off, and the balance can go below zero.
- A purchase is tested in Xcode's StoreKit testing and in TestFlight, which uses sandbox
  money, before it goes live.

### Step 4: The free trial

- The first time an account talks to the server, it gets 200 credits.
- **Against reinstalling for more:** the grant is tied to the `AppTransaction` id, and also to
  the device through Apple's **DeviceCheck**. One trial per device, even with a second Apple
  Account.
- The intro and the website say it plainly: "200 free credits, about 200 mails."

### Step 5: The Mac

The Mac beta is a DMG from the website (Developer ID). It **cannot** use App Store purchases.
Choices:

1. **Recommended: put the Mac app in the Mac App Store** as a *universal purchase* with the
   iPhone app. The same Apple Account then has one balance on both. iCloud also gets easier,
   because the DMG today has no iCloud.
2. Keep the DMG and let the Mac use credits bought on the iPhone. The Mac then needs a way to
   prove it is the same account, for example a code shown on the iPhone. This is more work,
   and harder to explain.
3. Keep the DMG with "own API key" only.

To decide before Step 5.

### Step 6: Words, law and the website

- **Privacy policy:** mail goes through the Matterbee server now, not only to the provider.
  Say what the server keeps (account, model, tokens, credits, time) and what it does not keep
  (any text). Mail is already disguised on the device before it leaves, and the policy says so.
  Name Anthropic, Mistral and OpenAI as providers who see the disguised text, and Cloudflare
  as the host.
- **Data processing agreements** with each provider and with Cloudflare.
- **Impressum** and **terms of use** on the website, because money is now involved.
- **Tax:** Apple sells, and pays the VAT. The payout from Apple is still income. Ask a tax
  advisor (Steuerberater) once: Kleinunternehmer or not.
- The website's download page says: free to try, then credits, or your own key.

## Risks

| Risk | What helps |
|---|---|
| A provider raises prices | Prices live on the server. Change the credits per model there, not the pack |
| A bug spends too much | The ledger shows every spend. A daily limit per account on the server (e.g. 1,000 credits) |
| Someone shares their token | Tokens are short-lived and come from the `AppTransaction`. One account, a few devices at most |
| The server is down | The app says so and offers "use my own API key" for the moment |
| The owner's API key leaks | It only lives in the Worker's secrets, never in the app or the repo |
| Too few buyers to cover the trials | Watch it after a month. Make the trial smaller, or stop it |

## Still open

1. The Mac: App Store, DMG with a code, or own key only? (Step 5)
2. ~~Does Ask Matterbee also send only disguised text?~~ **Yes** (checked 2026-10-01). Every
   question, summary and next step goes through `AssistantAsk.prepare`. Names, companies,
   e-mail addresses, phone numbers, IBANs and streets become stand-ins like `[Person A]`. Web
   links become `[Link 1]`. If the list of names can't be read, nothing is sent. What is *not*
   disguised: amounts, dates, and what the text is about. The privacy policy should say
   "names are hidden", not "anonymous". Optional extra guard: run `Prepared.leaks(...)` before
   every send in the app, not only in the tests.
3. GPT-6 Astra (about 20 credits a mail) only with an own key, or as a fourth choice?
