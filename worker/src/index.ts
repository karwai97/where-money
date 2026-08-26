// The only place the OpenAI key exists.
//
// Two things stand between a signed-in user and the model: the ID token, which
// says this is a user of this app, and the daily counter, which says they have
// not already had today's allowance. Everything else about the request — the
// prompt, the schema, the model, the output budget — belongs to the Worker,
// because a client that could name those is a client that could run up the
// bill.
//
// The model's response is returned as it arrived. The app parses it in Dart,
// where the interleaved reasoning items, the refusal block and the incomplete
// status are already tested.
//
// Two endpoints stand behind all of that: /extract turns a photographed
// receipt into an Extraction, and /recap turns a month's Rollup into prose.

import { reserve } from './allowance';
import type { Counted } from './allowance';
import { extractionBody, looksLikeBase64 } from './extraction_request';
import { readKnobs } from './knobs';
import { looksLikeRollup, recapBody } from './recap_request';
import { verifyIdToken } from './token';

// A receipt resized to ~1024px on the long edge is around 200KB, so ~270KB
// once base64 has grown it by a third. This leaves room for a phone that
// resized less aggressively and still keeps the CPU a Scan costs to a fifth of
// what the free plan allows — at ten times this, checking and encoding the
// string alone would be half the budget. bench/body-cpu.test.ts measures both.
const maxImageCharacters = 700_000;

// A Rollup measures about 1,600 characters and does not grow with the Ledger.
// Six times that is room to spare, and a body past it is not a Rollup.
const maxRollupCharacters = 10_000;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json(200, { ok: true });
    }
    if (url.pathname !== '/extract' && url.pathname !== '/recap') {
      return failure(404, 'not_found', 'No such endpoint.');
    }
    if (request.method !== 'POST') {
      return failure(
        405,
        'method_not_allowed',
        'Post the image to /extract, or the Rollup to /recap.',
      );
    }

    const caller = await callerOf(request, env);
    if ('refusal' in caller) return caller.refusal;

    return url.pathname === '/extract'
      ? extract(request, url, env, caller.uid)
      : recap(request, url, env, caller.uid);
  },
};

// Who is calling, or the refusal to send back instead. Both endpoints stand
// behind this: the token is what says the caller is a user of this app.
async function callerOf(
  request: Request,
  env: Env,
): Promise<{ uid: string } | { refusal: Response }> {
  const token = bearerToken(request.headers.get('authorization'));
  if (token === null) {
    return {
      refusal: failure(
        401,
        'missing_token',
        'Sign in and send your Firebase ID token.',
      ),
    };
  }

  const caller = await verifyIdToken(token, env.FIREBASE_PROJECT_ID);
  if (!caller.ok) {
    // Nothing the caller can do about our end of it, so it is not their token
    // being blamed.
    return {
      refusal: caller.ours
        ? failure(
            503,
            'signing_keys_unavailable',
            'Could not reach Google to check the token. Try again shortly.',
          )
        : failure(403, 'invalid_token', 'That token was not accepted.', {
            reason: caller.reason,
          }),
    };
  }

  return { uid: caller.uid };
}

async function extract(
  request: Request,
  url: URL,
  env: Env,
  uid: string,
): Promise<Response> {
  const tooLarge = () =>
    failure(413, 'image_too_large', 'Resize the image and send it again.');
  if (Number(request.headers.get('content-length')) > maxImageCharacters) {
    return tooLarge();
  }

  const image = await request.text();
  if (image.length > maxImageCharacters) {
    return tooLarge();
  }
  if (!looksLikeBase64(image)) {
    return failure(
      400,
      'bad_image',
      'The body must be the base64 of the image and nothing else.',
    );
  }

  const knobs = readKnobs(url, env.DAILY_MODEL_CEILING);

  const refusal = await spendAllowance(env, 'scans', uid, knobs.dailyCap);
  if (refusal) return refusal;

  return askTheModel(env, extractionBody(image, knobs));
}

async function recap(
  request: Request,
  url: URL,
  env: Env,
  uid: string,
): Promise<Response> {
  const tooLarge = () =>
    failure(413, 'rollup_too_large', 'That is larger than a Rollup.');
  if (Number(request.headers.get('content-length')) > maxRollupCharacters) {
    return tooLarge();
  }

  const rollup = await request.text();
  if (rollup.length > maxRollupCharacters) {
    return tooLarge();
  }
  if (!looksLikeRollup(rollup)) {
    return failure(400, 'bad_rollup', 'The body must be a Rollup as JSON.');
  }

  const knobs = readKnobs(url, env.DAILY_MODEL_CEILING);

  const refusal = await spendAllowance(env, 'recaps', uid, knobs.dailyCap);
  if (refusal) return refusal;

  return askTheModel(env, recapBody(rollup, knobs));
}

// The refusal to send back, or nothing when there was allowance to spend.
async function spendAllowance(
  env: Env,
  counted: Counted,
  uid: string,
  limit: number,
): Promise<Response | null> {
  const allowance = await reserve(env.MODEL_ALLOWANCE, {
    counted,
    uid,
    limit,
    now: Date.now(),
  });
  if (allowance.allowed) return null;

  return failure(
    429,
    'cap_reached',
    counted === 'scans'
      ? 'The daily Scan cap is reached.'
      : 'The daily Recap cap is reached.',
    {
      used: allowance.used,
      limit: allowance.limit,
      resets_at: allowance.resetsAt,
    },
  );
}

async function askTheModel(env: Env, body: string): Promise<Response> {
  let response: Response;
  try {
    response = await fetch(env.OPENAI_RESPONSES_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body,
    });
  } catch {
    return failure(502, 'model_unavailable', 'Could not reach the model.');
  }

  if (!response.ok) {
    return failure(502, 'model_unavailable', 'The model refused the request.', {
      upstream_status: response.status,
    });
  }

  return new Response(response.body, {
    status: 200,
    headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store',
    },
  });
}

function bearerToken(header: string | null): string | null {
  const match = /^Bearer (.+)$/i.exec(header?.trim() ?? '');
  return match?.[1] ?? null;
}

function failure(
  status: number,
  error: string,
  message: string,
  detail: Record<string, unknown> = {},
): Response {
  return json(status, { error, message, ...detail });
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store',
    },
  });
}
