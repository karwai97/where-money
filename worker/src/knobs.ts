// What the client is allowed to ask for.
//
// The model and the output budget belong to the Worker, not to the client: a
// modified client that could name a frontier model and a million output tokens
// would be an expensive problem, and the key lives here rather than there
// precisely so that it cannot. An unrecognised value falls back rather than
// failing the request, so a Remote Config typo degrades to the default instead
// of taking scanning down.

const allowedModels = ['gpt-5-nano', 'gpt-5-mini'];
const allowedEfforts = ['omit', 'none', 'minimal', 'low', 'medium', 'high'];
const allowedMediaTypes = ['image/jpeg', 'image/png', 'image/webp'];

const defaultModel = 'gpt-5-nano';
const defaultEffort = 'low';
const defaultMediaType = 'image/jpeg';

// Used when the deployment's ceiling is missing or unreadable. A typo in
// wrangler.jsonc has to land on a number that caps something, because the one
// unacceptable reading of a broken ceiling is "no cap at all".
const defaultCeiling = 40;

// Enough for a long receipt's worth of JSON plus its reasoning, and low enough
// that a runaway response is a rounding error. Output tokens cost 8x input on
// the nano tier, so this is the number that bounds what a Scan can cost.
export const maxOutputTokens = 8000;

export interface Knobs {
  model: string;
  effort: string;
  mediaType: string;
  dailyCap: number;
}

export function readKnobs(url: URL, configuredCeiling: string): Knobs {
  return {
    model: allowed(url.searchParams.get('model'), allowedModels, defaultModel),
    effort: allowed(
      url.searchParams.get('effort'),
      allowedEfforts,
      defaultEffort,
    ),
    mediaType: allowed(
      url.searchParams.get('media'),
      allowedMediaTypes,
      defaultMediaType,
    ),
    dailyCap: capUnder(
      url.searchParams.get('cap'),
      wholeNumber(configuredCeiling) ?? defaultCeiling,
    ),
  };
}

function allowed(
  asked: string | null,
  allowlist: string[],
  fallback: string,
): string {
  return asked !== null && allowlist.includes(asked) ? asked : fallback;
}

// Remote Config lowers the cap without a deploy; nothing raises it past the
// ceiling the deployment sets.
function capUnder(asked: string | null, ceiling: number): number {
  const wanted = wholeNumber(asked);
  return wanted === null ? ceiling : Math.min(wanted, ceiling);
}

function wholeNumber(text: string | null | undefined): number | null {
  const parsed = Number(text);
  return text === null || text === undefined || text === '' || !Number.isFinite(parsed)
    ? null
    : Math.max(0, Math.floor(parsed));
}
