// F004: each job the bee does has its model, in one table (jobs.json). The app sends the job in
// the `causabee-job` header; the server sets the job's model, refuses another, and sends what may
// wait on Flex — once more at the normal tier when Flex is busy.

import table from "./jobs.json";

export interface JobRow {
  name: string;
  model: string;
  flex: boolean;
  testing: string[];
}

export const jobs: Record<string, JobRow> = table.jobs;

/// A request from a build before F004 carries no job: it is answered as it asks, and counted so.
export const unknownJob = "unknown";

/// Flex may keep a request waiting; past this the server asks at the normal tier instead.
export const flexWaitMs = 60_000;

export type Choice = { job: string; model: string } | { refused: string };

/// The model a request is answered with. With a job: the job's model, set when the request names
/// none, refused when it names another. Without one: the model asked, if `allowed` takes it.
export function choose(job: string | null, asked: unknown, allowed: (model: string) => boolean): Choice {
  const named = typeof asked === "string" && asked !== "" ? asked : null;
  if (job === null || job === "") return named && allowed(named) ? { job: unknownJob, model: named } : { refused: named ?? "" };
  const row = jobs[job];
  if (!row) return { refused: named ?? job };
  if (named && named !== row.model) return { refused: named };
  return { job, model: row.model };
}

export type Tier = "flex" | "default";

/// Asks OpenAI once; for a job that may wait, on Flex first, and at the normal tier when Flex
/// answers 429 (not charged) or keeps it waiting past `flexWaitMs`.
export async function askOpenAI(body: Record<string, any>, job: string, send: (body: Record<string, any>, signal?: AbortSignal) => Promise<Response>): Promise<{ response: Response; tier: Tier }> {
  if (jobs[job]?.flex) {
    try {
      const response = await send({ ...body, service_tier: "flex" }, AbortSignal.timeout(flexWaitMs));
      if (response.status !== 429) return { response, tier: "flex" };
    } catch (error) {
      if ((error as Error)?.name !== "TimeoutError" && (error as Error)?.name !== "AbortError") throw error;
    }
  }
  const { service_tier: _, ...normal } = body;
  return { response: await send(normal), tier: "default" };
}

/// The tier OpenAI says it used, or the one asked for when the answer does not say.
export function tierUsed(answer: any, asked: Tier): Tier {
  const said = answer?.service_tier;
  if (said === "flex") return "flex";
  if (typeof said === "string") return "default";
  return asked;
}
