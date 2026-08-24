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

import { reserveScan } from './allowance';
import { extractionBody, looksLikeBase64 } from './extraction_request';
import { readKnobs } from './knobs';
import { verifyIdToken } from './token';

// A receipt resized to ~1024px on the long edge is around 200KB, so ~270KB
// once base64 has grown it by a third. This is generous enough for a phone
// that ignores the knob and tight enough that nobody posts a film.
const maxImageCharacters = 2_000_000;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json(200, { ok: true });
    }
    if (url.pathname !== '/extract') {
      return failure(404, 'not_found', 'No such endpoint.');
    }
    if (request.method !== 'POST') {
      return failure(405, 'method_not_allowed', 'Post the image to /extract.');
    }
    return extract(request, url, env);
  },
};

async function extract(request: Request, url: URL, env: Env): Promise<Response> {
  const token = bearerToken(request.headers.get('authorization'));
  if (token === null) {
    return failure(
      401,
      'missing_token',
      'Sign in and send your Firebase ID token.',
    );
  }

  const caller = await verifyIdToken(token, env.FIREBASE_PROJECT_ID);
  if (!caller.ok) {
    // Nothing the caller can do about our end of it, so it is not their token
    // being blamed.
    return caller.ours
      ? failure(
          503,
          'token_check_unavailable',
          'Could not reach Google to check the token. Try again shortly.',
        )
      : failure(403, 'invalid_token', 'That token was not accepted.', {
          reason: caller.reason,
        });
  }

  if (Number(request.headers.get('content-length')) > maxImageCharacters) {
    return failure(413, 'image_too_large', 'Resize the image and send it again.');
  }

  const image = await request.text();
  if (image.length > maxImageCharacters) {
    return failure(413, 'image_too_large', 'Resize the image and send it again.');
  }
  if (!looksLikeBase64(image)) {
    return failure(
      400,
      'bad_image',
      'The body must be the base64 of the image and nothing else.',
    );
  }

  const knobs = readKnobs(url, Number(env.DAILY_SCAN_CEILING));

  // Reserved before the call rather than counted after it: the cost is incurred
  // by the call, so a failure that did not reach the model still spends the
  // allowance. That is the cheap way round — refunding would need a second
  // write against an eventually consistent counter, and a cap with a race in it
  // is not a cap.
  const allowance = await reserveScan(env.SCAN_ALLOWANCE, {
    uid: caller.uid,
    limit: knobs.dailyCap,
    now: Date.now(),
  });
  if (!allowance.allowed) {
    return failure(429, 'cap_reached', 'The daily Scan cap is reached.', {
      used: allowance.used,
      limit: allowance.limit,
      resets_at: allowance.resetsAt,
    });
  }

  let response: Response;
  try {
    response = await fetch(env.OPENAI_RESPONSES_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: extractionBody(image, knobs),
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
