// The one performance risk in this Worker, measured — and the Recap beside it,
// because /recap does the parse and re-encode that /extract goes out of its way
// to avoid, and a claim that it is cheap at a kilobyte should be a number.
//
// The free plan allows 10ms of CPU per request. Waiting on fetch is exempt, so
// the model round trip is free, but the ~270KB base64 of a resized receipt is
// not. This runs the two things a request actually does to that string —
// checking it is base64, then templating it into the outgoing body — and prints
// what they cost, against the cost of the obvious alternative: taking the image
// out of a JSON envelope and serialising it back into another one.
//
// It runs in Node rather than in workerd on purpose: inside a Worker, timers do
// not advance during synchronous execution, so the runtime cannot time itself.
// Same V8, same string operations.

import { describe, expect, it } from 'vitest';

import { extractionBody, looksLikeBase64 } from '../src/extraction_request';
import type { Knobs } from '../src/knobs';
import { looksLikeRollup, recapBody } from '../src/recap_request';

const knobs: Knobs = {
  model: 'gpt-5-nano',
  effort: 'low',
  mediaType: 'image/jpeg',
  dailyCap: 40,
};

// Two sizes: what a Scan actually sends, and the largest body the endpoint
// accepts at all.
const sizes = {
  'a 1024px receipt (270KB of base64)': 270_000,
  'the largest body /extract takes': 700_000,
};
const runs = 100;

function millisPerRun(work: () => unknown): number {
  work();
  const started = performance.now();
  for (let i = 0; i < runs; i++) work();
  return (performance.now() - started) / runs;
}

describe('the CPU a Scan costs the Worker', () => {
  for (const [what, size] of Object.entries(sizes)) {
    it(`stays inside the 10ms the free plan allows, for ${what}`, () => {
      const image = 'A'.repeat(size);
      const encoder = new TextEncoder();

      const checking = millisPerRun(() => looksLikeBase64(image));
      // Concatenation is lazy in V8, so templating alone costs nothing until
      // something reads the whole string. fetch does, when it encodes the body,
      // and that is where the real cost of templating lands.
      const templatingAndEncoding = millisPerRun(() =>
        encoder.encode(extractionBody(image, knobs, 'en')),
      );
      // What the Worker would pay instead if the image arrived inside a JSON
      // envelope: the parse, and then the same encode on the way out.
      const envelope = JSON.stringify({ image });
      const parsing =
        millisPerRun(() => (JSON.parse(envelope) as { image: string }).image) +
        templatingAndEncoding;

      console.log(
        [
          what,
          `  checking it is base64:   ${checking.toFixed(3)}ms`,
          `  templating and encoding: ${templatingAndEncoding.toFixed(3)}ms`,
          `  per Scan, together:      ${(checking + templatingAndEncoding).toFixed(3)}ms`,
          `  parsing it out of JSON:  ${parsing.toFixed(3)}ms`,
        ].join('\n'),
      );

      expect(checking + templatingAndEncoding).toBeLessThan(5);
    });
  }
});

// A month of the Ledger reduced to totals, deltas and outliers, at the size
// rollupPrompt actually produces: 12 categories, five largest purchases.
const rollup = JSON.stringify({
  month: 'August 2026',
  currency: 'MYR',
  total: 1806.75,
  previous_month: 'July 2026',
  previous_total: 1262.1,
  expenses: 18,
  daily_average: 58.28,
  by_category: Array.from({ length: 12 }, (_, i) => ({
    category: `Category number ${i}`,
    amount: 423.1,
    previous: 289.6,
    count: 3,
  })),
  largest: Array.from({ length: 5 }, (_, i) => ({
    merchant: `A merchant with a fairly long name ${i}`,
    amount: 289.9,
    category: 'Home',
    day: 23,
  })),
  heaviest_day: { day: 23, amount: 311.9 },
  excluded: { count: 1, currencies: ['USD'] },
});

describe('the CPU a Recap costs the Worker', () => {
  it('is a rounding error beside a Scan, parse and re-encode included', () => {
    const encoder = new TextEncoder();

    const checking = millisPerRun(() => looksLikeRollup(rollup));
    const buildingAndEncoding = millisPerRun(() =>
      encoder.encode(recapBody(rollup, knobs, 'en')),
    );

    console.log(
      [
        `a Rollup (${rollup.length} characters)`,
        `  checking it is JSON:     ${checking.toFixed(3)}ms`,
        `  building and encoding:   ${buildingAndEncoding.toFixed(3)}ms`,
        `  per Recap, together:     ${(checking + buildingAndEncoding).toFixed(3)}ms`,
      ].join('\n'),
    );

    expect(checking + buildingAndEncoding).toBeLessThan(0.5);
  });
});
