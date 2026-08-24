// Building the request body without touching the image.
//
// The free plan allows 10ms of CPU per request. Waiting on fetch is exempt, so
// the model round trip is free, but a ~270KB base64 string is not: parsing it
// out of an incoming JSON envelope and serialising it back into an outgoing one
// is the one thing here that could spend the whole budget. So the client sends
// the base64 as the entire request body, the static halves of the outgoing body
// are built once per knob combination and kept in the isolate, and a request is
// one concatenation. scripts/measure-body-cpu.ts has the numbers.

import type { Knobs } from './knobs';
import { maxOutputTokens } from './knobs';
import {
  extractionInstructions,
  extractionUserText,
  receiptSchema,
} from './schema';

const schemaJson = JSON.stringify(receiptSchema);
const instructionsJson = JSON.stringify(extractionInstructions);
const userTextJson = JSON.stringify(extractionUserText);

const templates = new Map<string, [prefix: string, suffix: string]>();

export function extractionBody(imageBase64: string, knobs: Knobs): string {
  const [prefix, suffix] = templateFor(knobs);
  return prefix + imageBase64 + suffix;
}

// The base64 alphabet cannot close a JSON string, so a body templated around
// something that passes this cannot be steered by its own image — which is what
// makes the model allowlist worth anything.
export function looksLikeBase64(text: string): boolean {
  return /^[A-Za-z0-9+/=\r\n]+$/.test(text);
}

function templateFor(knobs: Knobs): [string, string] {
  const cacheKey = `${knobs.model}|${knobs.effort}|${knobs.mediaType}`;
  const cached = templates.get(cacheKey);
  if (cached) return cached;

  const reasoning =
    knobs.effort === 'omit' ? '' : `"reasoning":{"effort":"${knobs.effort}"},`;
  const template: [string, string] = [
    `{"model":"${knobs.model}",` +
      `"instructions":${instructionsJson},` +
      `"max_output_tokens":${maxOutputTokens},` +
      reasoning +
      `"text":{"format":{"type":"json_schema","name":"receipt_extraction",` +
      `"strict":true,"schema":${schemaJson}}},` +
      `"input":[{"role":"user","content":[` +
      `{"type":"input_image","detail":"auto",` +
      `"image_url":"data:${knobs.mediaType};base64,`,
    `"},{"type":"input_text","text":${userTextJson}}]}]}`,
  ];
  templates.set(cacheKey, template);
  return template;
}
