// The per-user daily cap, so one account cannot run up the bill.
//
// The reservation is taken before the model is called, not after: the cost is
// incurred by the call, and a client that could retry a failed call for free
// would be a cap with a hole in it.

export interface Allowance {
  allowed: boolean;
  used: number;
  limit: number;
  resetsAt: string;
}

// Two days, so a counter outlives the day it belongs to and nothing else has
// to clean up.
const keepForSeconds = 2 * 24 * 60 * 60;

export async function reserveScan(
  counters: KVNamespace,
  { uid, limit, now }: { uid: string; limit: number; now: number },
): Promise<Allowance> {
  const resetsAt = startOfNextDay(now);
  const key = `scans:${uid}:${dayOf(now)}`;
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
