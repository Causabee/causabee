// What a request costs, worked out the way the app does it (`Claude.Model.cost` in
// Sources/MatterCore/Claude.swift): dollars per million tokens, written and read cache at 1.25 and
// 0.1 of the input price. Kept in micro-dollars, so the ledger adds whole numbers.

export interface Price {
  inputPerMillion: number;
  outputPerMillion: number;
  /// A cached read, where OpenAI prices it apart; otherwise a tenth of the input.
  cachedPerMillion?: number;
}

/// The models the app may ask through the server. A model not here is refused: nothing is passed
/// on that cannot be counted.
export const prices: Record<string, Price> = {
  "claude-opus-5": { inputPerMillion: 5, outputPerMillion: 25 },
  "claude-sonnet-5": { inputPerMillion: 2, outputPerMillion: 10 },
  "claude-haiku-4-5": { inputPerMillion: 1, outputPerMillion: 5 },
  "gpt-6.1-sol": { inputPerMillion: 2, outputPerMillion: 10, cachedPerMillion: 0.1 },
  "gpt-6.1-terra": { inputPerMillion: 1, outputPerMillion: 5, cachedPerMillion: 0.05 },
  "gpt-6-luna": { inputPerMillion: 0.1, outputPerMillion: 0.5, cachedPerMillion: 0.01 },
};

/// Flex is half of every price, the same as Batch (F004 AC-4).
export const flexShare = 0.5;

/// A web search the model ran itself costs on top: ten dollars a thousand, at both providers.
export const microsPerSearch = 10_000;

export interface Usage {
  input: number;
  output: number;
  cacheWrite: number;
  cacheRead: number;
  searches: number;
}

export function costMicros(model: string, usage: Usage, tier: "flex" | "default" = "default"): number | null {
  const price = prices[model];
  if (!price) return null;
  const dollars =
    (usage.input * price.inputPerMillion +
      usage.output * price.outputPerMillion +
      usage.cacheWrite * price.inputPerMillion * 1.25 +
      usage.cacheRead * (price.cachedPerMillion ?? price.inputPerMillion * 0.1)) /
    1_000_000;
  const share = tier === "flex" ? flexShare : 1;
  return Math.ceil(dollars * share * 1_000_000) + usage.searches * microsPerSearch;
}

/// Anthropic's `usage`: input, output, the cache written and read, and the searches the server tool ran.
export function anthropicUsage(body: any): Usage {
  const u = body?.usage ?? {};
  return {
    input: u.input_tokens ?? 0,
    output: u.output_tokens ?? 0,
    cacheWrite: u.cache_creation_input_tokens ?? 0,
    cacheRead: u.cache_read_input_tokens ?? 0,
    searches: u.server_tool_use?.web_search_requests ?? 0,
  };
}

/// OpenAI's Responses `usage`: input with the parts read from and written to the cache inside it,
/// output; a web search shows as an output item of its own.
export function openAIUsage(body: any): Usage {
  const u = body?.usage ?? {};
  const cached = u.input_tokens_details?.cached_tokens ?? 0;
  const written = u.input_tokens_details?.cache_write_tokens ?? 0;
  const searches = Array.isArray(body?.output) ? body.output.filter((o: any) => o?.type === "web_search_call").length : 0;
  return {
    input: Math.max(0, (u.input_tokens ?? 0) - cached - written),
    output: u.output_tokens ?? 0,
    cacheWrite: written,
    cacheRead: cached,
    searches,
  };
}
