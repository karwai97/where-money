// The per-user daily cap, so one account cannot run up the bill.
//
// Scans and Recaps are counted separately under the same ceiling. Both cost
// money and both are capped; what they must not do is spend each other's
// allowance, because a month's worth of Recaps eating the day's Scans would
// make the cap fail at the job it exists for.
//
// Reserved before the model is called rather than counted after: the call is
// what costs, so a Scan that failed on its way to the model still spends the
// allowance. Refunding would mean a second write, and the counter is already
// approximate — KV reads what it last replicated, so two Scans at once, or two
// Scans in two places, can read the same number and both be allowed. The cap
// bounds the bill; it is not an exact quota, and nothing here pretends it is.

export interface Allowance {
  allowed: boolean;
  used: number;
  limit: number;
  resetsAt: string;
}

// Two days, so a counter outlives the day it belongs to and nothing else has
// to clean up.
const keepForSeconds = 2 * 24 * 60 * 60;

export type Counted = 'scans' | 'recaps';

export async function reserve(
  counters: KVNamespace,
  {
    counted,
    uid,
    limit,
    now,
  }: { counted: Counted; uid: string; limit: number; now: number },
): Promise<Allowance> {
  const resetsAt = startOfNextDay(now);
  const key = `${counted}:${uid}:${dayOf(now)}`;
  const used = Number((await counters.get(key)) ?? 0) || 0;

  if (used >= limit) {
    return { allowed: false, used, limit, resetsAt };
  }

  await counters.put(key, String(used + 1), {
    expirationTtl: keepForSeconds,
  });
  return { allowed: true, used: used + 1, limit, resetsAt };
}

function dayOf(now: number): string {
  return new Date(now).toISOString().slice(0, 10);
}

function startOfNextDay(now: number): string {
  const date = new Date(now);
  date.setUTCHours(0, 0, 0, 0);
  return new Date(date.getTime() + 24 * 60 * 60 * 1000).toISOString();
}
