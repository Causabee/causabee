# F004 · The right model for each job — Looks

## Screens and states

No new screen. Where the app or the website names the AI, it names the model of the job — the one that wrote what is shown. The names come from the table (`jobs.json` / `AIJob`), so they follow it when a job moves; below, `{read}` and `{brief}` stand for the model the tests leave each job with, Luna, Terra or Sol.

| Where | Today | After |
|---|---|---|
| Mac, iPhone, iPad · a chat answer, beside its sources | "OpenAI GPT-6.1 Sol" | unchanged: the chat stays on Sol |
| Mac, iPhone, iPad · the line while what came in is sorted | "Sorting in 3 mails with Causabee Pro. Sent pseudonymised to OpenAI GPT-6.1 Sol." | "… Sent pseudonymised to OpenAI **{read}**." |
| Mac, iPhone, iPad · the journal note when something is taken in | "📥 2 mails taken in · 2 new tasks · sorted by GPT-6.1 Sol" | "… · sorted by **{read}**" — the model that sorted it, as it was then |
| Mac, iPhone, iPad · under a matter's next step and summary | "⚡ Pro" | "⚡ Pro · **{brief}**" |
| Mac · Settings › About | "Everything is read with OpenAI GPT-6.1 Sol: through the beeserver with Pro, or with your own key." | the job table, see Words |
| The demo | "sorted by GPT-6.1 Sol" in its notes | "sorted by **{read}**", so the demo shows what the app does |

States:
- **With Pro:** as above.
- **With your own OpenAI key:** the same table — the own key is asked for the same model per job.
- **Without Pro:** unchanged: Apple's model on macOS 26 and iOS 26, or threads and senders. No OpenAI model is named.
- **A job that moved back to Sol** (its test failed later): it shows Sol again; nothing else changes.

## Words

| Where | New |
|---|---|
| Settings › About, with Pro or an own key | **Read and sorted with OpenAI {read}. Each matter's brief and next step with OpenAI {brief}. The chat with OpenAI GPT-6.1 Sol. Each model was chosen only after it did its job as well as Sol. All of them get only pseudonymised text.** |
| The line under a next step or summary | **Pro · {brief}** (the short name: "GPT-6.1 Terra", "GPT-6 Luna", "GPT-6.1 Sol") |
| causabee.app · Be private · the heading "One AI, only with Pro" | **OpenAI, only with Pro** |
| causabee.app · its text | **With Causabee Pro, OpenAI's GPT-6.1 Sol answers you in the chat; {read} reads what comes in, and {brief} writes each matter's brief — each chosen only after it did its job as well as Sol.** Then, as today: "Without Pro, Apple's model sorts what comes in on macOS 26, and nothing leaves your Mac. On macOS 15, Causabee sorts by thread and sender." |
| causabee.app · the bee's map, "External AI" | the chips **OpenAI GPT-6.1 Sol · {read} · {brief}** (each once), **with Causabee Pro** |
| Release notes | **The bee costs less: each job uses the smallest OpenAI model that does it as well as GPT-6.1 Sol.** |

If both `{read}` and `{brief}` stay on Sol, the website and Settings keep their words of today, and only "sorted by" and "Pro" lines name Sol as now.

## On each device

The same words on the Mac, the iPad and the iPhone; the iPhone's and the iPad's next-step line is the same as the Mac's. Settings' line is on the Mac only, as today.

## Undo, and what the user can take back

Not needed: nothing the user does changes. The model of a job is the owner's, in the table.

## Accessibility

VoiceOver reads the next step's line as "Pro, written by OpenAI {brief}". The model names are text, not an image; at the largest text size the line wraps under the step, as the "Pro" line does today.

## Picture

No screen changes beyond a few words. The owner sees them in the app after the build, in the demo, on all three devices.
