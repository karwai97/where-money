// Building the recap request.
//
// The prompt is the Rollup and never the Ledger, and a Rollup is about a
// kilobyte however long the Ledger under it is.
//
// /extract templates around its body because parsing a ~270KB base64 string
// out of one JSON envelope and back into another is most of the CPU a request
// is allowed. This endpoint does parse and re-encode, because at a kilobyte
// that costs a hundredth of a millisecond — bench/body-cpu.test.ts measures
// both rather than leaving it as a claim.
//
// No schema. What comes back is prose, which is what the screen wants, and the
// app reads it with the same walk that reads an Extraction.

import { languageName } from './language';
import type { Knobs } from './knobs';

const maxRecapOutputTokens = 4000;

const recapInstructions = `You are writing a short account of one month of somebody's spending, for the person who spent it.

You are given a Rollup: the month's total and the previous month's, totals by category for both, how many Expenses there were and the daily average, the largest purchases, the heaviest day, and a count of anything left out for being in another currency. That is everything you have. Never state a figure that is not in it and never guess what a purchase was for.

The Rollup carries no words. The month is a "year" and a "month", where the month is 1 for January, and the one before it is "previous_year" and "previous_month". Categories arrive as slugs such as "personal_care" and "fees_charges". Name the month and the categories in ordinary words when you write about them.

Write three to five short sentences of plain prose. No headings, no lists, no markdown. Say which categories moved and by how much, name the largest purchases, and say which day cost the most. Use the currency code and the amounts exactly as they are given.

The month may still be in progress, so compare it against the previous month as it stands rather than predicting where it will end up. If any spending was left out for being in another currency, say so in a clause rather than a sentence of its own. Address the reader as "you".`;

// The instruction is the same prose plus one sentence naming the language, so
// no language is the special case. Built once each because there are two of
// them and a Recap is not the place to spend CPU on JSON.stringify.
const instructionsByLanguage = new Map<string, string>();

function instructionsJsonIn(language: string): string {
  const held = instructionsByLanguage.get(language);
  if (held) return held;

  const name = languageName(language);
  const built = JSON.stringify(
    `${recapInstructions}

Write in ${name}. Merchant names stay exactly as they are given, whatever language they are in.`,
  );
  instructionsByLanguage.set(language, built);
  return built;
}

export function recapBody(
  rollupJson: string,
  knobs: Knobs,
  language: string,
): string {
  const reasoning =
    knobs.effort === 'omit' ? '' : `"reasoning":{"effort":"${knobs.effort}"},`;

  return (
    `{"model":"${knobs.model}",` +
    // Somebody's month, itemised. The API keeps each response for later
    // retrieval unless told not to, and nothing here ever reads one back.
    `"store":false,` +
    `"instructions":${instructionsJsonIn(language)},` +
    `"max_output_tokens":${maxRecapOutputTokens},` +
    reasoning +
    `"input":[{"role":"user","content":[` +
    `{"type":"input_text","text":${JSON.stringify(rollupJson)}}]}]}`
  );
}

// A JSON object, which is what a Rollup is. It says the client sent something
// this endpoint is for; it does not say the contents are a Rollup, and nothing
// here needs it to — the prompt is quoted into the body as one string, so its
// contents cannot steer the request whatever they are.
export function looksLikeRollup(text: string): boolean {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return false;
  }
  return typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed);
}
