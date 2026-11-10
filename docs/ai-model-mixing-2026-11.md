# Mixing models to save tokens — research, 10 November 2026

Asked by the owner before F004: how Sol, Terra, an older or smaller OpenAI model could be mixed, simply, so the bee costs less. Prices are from OpenAI's own pricing page (`developers.openai.com/api/docs/pricing`, read 10 November); the rest is marked where it comes from.

## 1. What OpenAI offers today

Per million tokens, standard tier, prompts up to 272K tokens.

| Model | In | Cached in | Out | vs Sol |
|---|---|---|---|---|
| gpt-6-astra | $10.00 | $1.00 | $50.00 | 5× |
| **gpt-6.1-sol** (today, everything) | $2.00 | $0.10 | $10.00 | 1 |
| **gpt-6.1-terra** | $1.00 | $0.05 | $5.00 | ½ |
| **gpt-6-luna** | $0.10 | $0.01 | $0.50 | **1/20** |
| gpt-5.6-luna (older) | $0.20 | $0.02 | $1.20 | ~1/10 |
| gpt-5-mini (older) | $0.25 | $0.025 | $2.00 | ~1/7 |
| gpt-5-nano (older) | $0.05 | $0.005 | $0.40 | ~1/30 |
| gpt-4.1-mini (older) | $0.40 | $0.10 | $1.60 | ~1/6 |

- **Flex** (`service_tier: "flex"`): the Batch price — **half** — for the same model, answered in the same request, only slower; it may answer "resource unavailable" (not charged), then one tries again or falls back to the normal tier. Offered for Sol, Terra, Luna and most others. (Flex guide)
- **Batch**: also half, but answers come within 24 hours. Up to 50,000 requests a batch. (Batch guide)
- **Fast**: double the price, for speed. Not for us.
- **Prompt caching** (caching guide), on GPT-5.6 and later:
  - on by default, from 1,024 tokens of prompt; only an **identical prefix** is cached: stable instructions first, what changes last;
  - a cached read costs **0.05×** the input price on Sol and Terra (0.1× elsewhere);
  - **a cache write costs 1.25×** the input price (30-minute life, the default) or 2.5× (12 hours). Older models charge nothing for the write, but discount the read less.
  - `prompt_cache_key` keeps one user's requests on the same cache.
- **Terra is offered.** A router vendor's blog says "Terra retired" in its address; its own text and the official page say only that GPT-6 had no Terra for five weeks, until GPT-6.1 Terra on 26 October. (getnadir.com, a party that sells routing)
- **How hard the model thinks** (`reasoning.effort`: none, minimal, low, medium, high) changes the hidden thinking tokens, which are paid as output. OpenAI calls minimal right for extraction, formatting and simple classification. Which models take which values differs; one third-party page says Sol takes neither none nor minimal — not checked with OpenAI. (OpenAI reasoning guide and cookbook)
- **Luna's quality:** third-party benchmarks put it clearly below Sol overall (Vals Index 58% vs 63%, at about 1/18 of the cost per test; on other averages a gap of 6 points), with no benchmark of extraction or classification found. Only our own test can say whether it reads a care mail well enough.

## 2. What the research says about mixing

- **Routing** (choose a model before asking) and **cascades** (ask a cheap one first, a better one only if needed) are well studied: FrugalGPT (2023), RouteLLM (2024: about 3.7× cheaper at 95% of GPT-4's quality on one benchmark), Hybrid LLM (2024: 40% fewer calls to the big model), Cascade routing (ICML 2025), MixLLM (2025). (summaries in Stanford's review of routing and cascades, and the papers' own pages)
- **Everything rests on knowing when the cheap answer is not good enough.** The model's own confidence is poorly calibrated; a weak signal eats most of the saving, and a cascade that escalates pays twice. (Stanford review; blogs, not peer reviewed)
- A **learned router is for unknown questions.** Our jobs are known in the code, each with its own prompt and schema: a fixed table "this job, this model", tested once per job, needs no router and costs nothing to run.
- Vendor claims of "40–85% less" are not from papers; ours must come from our own ledger.

## 3. Our jobs

| Job | Where | Thinks | When it may wait |
|---|---|---|---|
| Reading what comes in: which matter, what it brings | `Extractor` + `ExtractionPrompt` | as set | yes — it sorts what came in overnight, in the background |
| A digest of one mail or file | `Digests` + `DigestPrompt` | low | yes |
| A matter's brief, summary and next step | `AdviserPrompt` | low | mostly — the owner sees "Causabee is on it …" |
| The chat: answers, drafts, suggestions | `Assistant` + `AssistantPrompt` | medium | no — someone waits |
| Which to-dos are the same | `Judge` | low | the test spike only |

Today's request, on average (ledger, 27 Oct–10 Nov): about 6,400 tokens in, 840 out; **about 60% of the cost is what is sent**, and only about a fifth of it is read from the cache.

## 4. What one request costs on each model

Our average request, without the cache: 6,400 in, 840 out.

| | Standard | Flex |
|---|---|---|
| Sol | 2.12 ¢ | 1.06 ¢ |
| Terra | 1.06 ¢ | 0.53 ¢ |
| Luna | 0.11 ¢ | 0.05 ¢ |

## 5. Three easy ways, together

1. **A fixed model per job**, in one table the server enforces — no router.
   - Reading and digests: Luna (or Terra, if Luna fails its test), on Flex, since they may wait.
   - The brief and next step: Terra, on Flex.
   - The chat: Sol, as now.
2. **Flex for every job that may wait** — half the price, same model, same request; on "resource unavailable", the normal tier.
3. **Use the cache on purpose.**
   - Order every prompt: the instructions and the schema first (they are the same for every request of a job), then the matters known, then the one new thing last.
   - A `prompt_cache_key` per user.
   - Keep the 30-minute life: a 12-hour write costs twice as much.
   - With 60% of the cost in what is sent, every prompt token read from the cache at 0.05× counts.

Two more, smaller:

- **Think less where it is not needed:** the lowest effort each model takes for reading and digests; **fewer output tokens** — short field names in the schemas, no reasons asked for that nothing shows, a cap on the answer's length. Output is 40% of the cost.
- **Escalate only on a clear signal**, if a cheap model is used for reading: its answer fails the schema, names a matter that does not exist, or says it found no matter — then that one item goes to Sol. Never on the model's own "I am unsure".

## 6. What it could come to — an illustration, not a measurement

The ledger cannot yet say how the 567 requests split between jobs. **If** reading and digests are 60% of the requests, the brief 20% and the chat 20%, and all are of average size:

| Mix | A request, on average | A heavy month |
|---|---|---|
| All on Sol (today) | 2.1 ¢ | ~$26 |
| All on Terra | 1.1 ¢ | ~$13 |
| Reading and digests on Luna Flex, brief on Terra Flex, chat on Sol | 0.56 ¢ | ~$7 |
| The same, with the cache used on purpose | less — how much, the ledger will say | |

Chat requests carry more context than the average, so the true mix may sit higher. The first thing to build is what the ledger is missing: **each request carries its job**, so the real split, and every saving, is measured, not guessed.

## 7. What only our own test can answer

- Does Luna read a German care letter, a WhatsApp screenshot and a mail thread as well as Sol — the right matter, the right tasks and dates? `matter-spike pressure` with the golden set, per job, before any job moves.
- Does Terra write a brief and a next step the owner cannot tell from Sol's?
- How often does Flex answer "unavailable", and how much later does the bee then sort?

## Sources

- OpenAI, pricing: https://developers.openai.com/api/docs/pricing
- OpenAI, prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- OpenAI, Flex processing: https://developers.openai.com/api/docs/guides/flex-processing
- OpenAI, Batch: https://developers.openai.com/api/docs/guides/batch
- OpenAI, reasoning: https://developers.openai.com/api/docs/guides/reasoning.md · cookbook: https://developers.openai.com/cookbook/examples/gpt-5/gpt-5_new_params_and_tools
- Routing and cascades, a review: https://web.stanford.edu/~shuhuiq/blog/review-routing-cascades.html · Cascade routing (ICML 2025): https://icml.cc/virtual/2025/poster/46183 · RouteLLM arXiv 2406.18665, Hybrid LLM arXiv 2404.14618, MixLLM arXiv 2502.18482
- Luna vs Sol, third party: https://www.vals.ai/models/openai_gpt-6-luna · https://www.datalearner.com/en/benchmark-compare/gpt-6-luna/gpt-6-sol · https://benchlm.ai/compare/gpt-6-1-sol-vs-gpt-6-luna
- Terra, third party: https://getnadir.com/blog/gpt-6-sol-luna-pricing-terra-retired-routing/ · https://www.eesel.ai/blog/gpt-6-1-terra
