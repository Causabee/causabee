// A month of Pro as the subscription has it: from the day it was first bought, not the calendar's.
// Bought on the 28th, the month runs from each 28th to the next — the 30th of a 31-day month in a
// shorter one runs to its last day. Accounts made by hand keep the calendar month.

export interface Cycle {
  /// What the ledger counts the month by: "2026-10-28", or "2026-10" for the calendar month.
  key: string;
  /// When it starts anew, "2026-11-28".
  renewsOn: string;
}

const iso = (d: Date) => d.toISOString().slice(0, 10);

/// The day in a month, held to its last day: the 31st in November is the 30th.
function on(year: number, month: number, day: number): Date {
  const last = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return new Date(Date.UTC(year, month, Math.min(day, last)));
}

export function cycle(anchor: string | null | undefined, now = new Date()): Cycle {
  if (!anchor) {
    return { key: now.toISOString().slice(0, 7), renewsOn: iso(new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1))) };
  }
  const day = new Date(anchor).getUTCDate();
  let start = on(now.getUTCFullYear(), now.getUTCMonth(), day);
  if (start > now) start = on(now.getUTCFullYear(), now.getUTCMonth() - 1, day);
  const next = on(start.getUTCFullYear(), start.getUTCMonth() + 1, day);
  return { key: iso(start), renewsOn: iso(next) };
}
