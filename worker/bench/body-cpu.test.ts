// The one performance risk in this Worker, measured.
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

const knobs: Knobs = {
  model: 'gpt-5-nano',
  effort: 'low',
  mediaType: 'image/jpeg',
  dailyCap: 40,
};

// A 1024px-long-edge receipt is around 200KB of JPEG, so around 270KB of
// base64.
const image = 'A'.repeat(270_000);
const runs = 200;

function millisPerRun(work: () => unknown): number {
  work();
  const started = performance.now();
  for (let i = 0; i < runs; i++) work();
  return (performance.now() - started) / runs;
}

describe('the CPU a Scan costs the Worker', () => {
  it('stays far inside the 10ms the free plan allows', () => {
    const checking = millisPerRun(() => looksLikeBase64(image));
    const templating = millisPerRun(() => extractionBody(image, knobs));
    // Concatenation is lazy in V8, so the join above costs nothing until
    // something reads the whole string. fetch does, when it encodes the body,
    // and that is where the real cost of templating lands.
    const encoder = new TextEncoder();
    const encoding = millisPerRun(() =>
      encoder.encode(extractionBody(image, knobs)),
    );
    const envelope = JSON.stringify({ image, knobs });
    const parsing = millisPerRun(() => {
      const incoming = JSON.parse(envelope) as { image: string };
      return JSON.stringify({ image_url: `data:image/jpeg;base64,${incoming.image}` });
    });

    console.log(
      [
        `checking the base64: ${checking.toFixed(3)}ms`,
        `templating the body: ${templating.toFixed(3)}ms`,
        `templating and encoding: ${encoding.toFixed(3)}ms`,
        `per Scan, together: ${(checking + encoding).toFixed(3)}ms`,
        `parsing instead:     ${parsing.toFixed(3)}ms`,
      ].join('\n'),
    );

    expect(checking + encoding).toBeLessThan(2);
  });
});
