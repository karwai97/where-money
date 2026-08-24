import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';

import { reserveScan } from '../src/allowance';

const noon = Date.parse('2026-08-24T12:00:00Z');
const laterThatDay = Date.parse('2026-08-24T23:59:00Z');
const nextMorning = Date.parse('2026-08-25T07:00:00Z');

const reserve = (uid: string, limit: number, now: number) =>
  reserveScan(env.SCAN_ALLOWANCE, { uid, limit, now });

describe("a user's daily allowance", () => {
  it('counts the first Scan of the day', async () => {
    const outcome = await reserve('uid-first', 3, noon);

    expect(outcome.allowed).toBe(true);
    expect(outcome.used).toBe(1);
  });

  it('counts up as the day goes on', async () => {
    await reserve('uid-counting', 5, noon);
    await reserve('uid-counting', 5, noon);
    const third = await reserve('uid-counting', 5, laterThatDay);

    expect(third.used).toBe(3);
    expect(third.allowed).toBe(true);
  });

  it('refuses the Scan that would go past the cap', async () => {
    await reserve('uid-capped', 2, noon);
    await reserve('uid-capped', 2, noon);

    const refused = await reserve('uid-capped', 2, noon);

    expect(refused.allowed).toBe(false);
    expect(refused.used).toBe(2);
    expect(refused.limit).toBe(2);
  });

  it('does not keep counting once it has refused', async () => {
    await reserve('uid-stuck', 1, noon);
    await reserve('uid-stuck', 1, noon);
    const refused = await reserve('uid-stuck', 1, noon);

    expect(refused.used).toBe(1);
  });

  it('is separate from the allowance of another user', async () => {
    await reserve('uid-alice', 1, noon);

    const bob = await reserve('uid-bob', 1, noon);

    expect(bob.allowed).toBe(true);
    expect(bob.used).toBe(1);
  });

  it('starts again the next day', async () => {
    await reserve('uid-tomorrow', 1, noon);
    expect((await reserve('uid-tomorrow', 1, laterThatDay)).allowed).toBe(false);

    const tomorrow = await reserve('uid-tomorrow', 1, nextMorning);

    expect(tomorrow.allowed).toBe(true);
    expect(tomorrow.used).toBe(1);
  });

  it('says when it resets, so the app can say "tomorrow" rather than "sorry"', async () => {
    const outcome = await reserve('uid-resets', 1, laterThatDay);

    expect(outcome.resetsAt).toBe('2026-08-25T00:00:00.000Z');
  });

  it('refuses everything when the cap is zero', async () => {
    const outcome = await reserve('uid-zero', 0, noon);

    expect(outcome.allowed).toBe(false);
    expect(outcome.used).toBe(0);
  });
});
