// Against the local Workers runtime, with Google's signing keys and the model
// both intercepted. The signing keys are published exactly once for the whole
// file, so every request after the first is served from the isolate's cache —
// if that cache stopped working, everything below would start failing.

import { fetchMock, SELF } from 'cloudflare:test';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import modelResponse from './fixtures/model-response.json?raw';
import { makeSigningKey, publishSigningKeys, signIdToken } from './support';
import type { SigningKey } from './support';

const modelOrigin = 'https://api.openai.test';
const modelPath = '/v1/responses';

// A stand-in for a photographed receipt at the size the app sends: base64, and
// long enough that the templating this endpoint is built around is doing real
// work.
const receiptImage = 'A'.repeat(270_000);

let key: SigningKey;
let sentBodies: string[] = [];

beforeAll(async () => {
  key = await makeSigningKey('kid-published-once');
  publishSigningKeys([key], { times: 1, maxAge: 3600 });
});

beforeEach(() => {
  sentBodies = [];
});

function expectModelCall({
  times = 1,
  status = 200,
  body = modelResponse,
}: { times?: number; status?: number; body?: string } = {}) {
  fetchMock
    .get(modelOrigin)
    .intercept({
      path: modelPath,
      method: 'POST',
      // The key is the reason this Worker exists, so a call made without it
      // matches nothing and fails rather than quietly succeeding.
      headers: { authorization: 'Bearer test-key-not-a-real-one' },
      body: (sent) => {
        sentBodies.push(sent);
        return true;
      },
    })
    .reply(status, body, { headers: { 'content-type': 'application/json' } })
    .times(times);
}

const sentToModel = () => JSON.parse(sentBodies[0]!) as Record<string, any>;

function scan(
  token: string | null,
  { query = '', image = receiptImage }: { query?: string; image?: string } = {},
) {
  return SELF.fetch(`https://worker.test/extract${query}`, {
    method: 'POST',
    headers: {
      'content-type': 'text/plain',
      ...(token === null ? {} : { authorization: `Bearer ${token}` }),
    },
    body: image,
  });
}

describe('a Scan', () => {
  it('is refused outright when the caller sent no token', async () => {
    const response = await scan(null);

    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ error: 'missing_token' });
  });

  it('is refused differently when the token is not one of ours', async () => {
    const response = await scan('not.a.token');

    expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({
      error: 'invalid_token',
      reason: 'malformed',
    });
  });

  it('is refused when the token has expired', async () => {
    const past = Math.floor(Date.now() / 1000) - 7200;

    const response = await scan(
      await signIdToken(key, { iat: past, exp: past + 3600 }),
    );

    expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({
      error: 'invalid_token',
      reason: 'expired',
    });
  });

  it('returns the model response exactly as it arrived, for the app to parse', async () => {
    expectModelCall();

    const response = await scan(await signIdToken(key, { sub: 'uid-verbatim' }));

    expect(response.status).toBe(200);
    expect(await response.text()).toBe(modelResponse);
  });

  it('sends the image to the model as the data URL the API wants', async () => {
    expectModelCall();

    await scan(await signIdToken(key, { sub: 'uid-image' }));

    expect(sentToModel().input[0].content[0].image_url).toBe(
      `data:image/jpeg;base64,${receiptImage}`,
    );
  });

  it('asks for the receipt schema in strict mode', async () => {
    expectModelCall();

    await scan(await signIdToken(key, { sub: 'uid-schema' }));

    const format = sentToModel().text.format;
    expect(format.strict).toBe(true);
    expect(format.schema.additionalProperties).toBe(false);
    expect(format.schema.required).toContain('total');
  });

  it('is sent to a model from the allowlist, whatever the client asked for', async () => {
    expectModelCall();

    await scan(await signIdToken(key, { sub: 'uid-allowlist' }), {
      query: '?model=gpt-5-pro&max_output_tokens=999999',
    });

    expect(sentToModel().model).toBe('gpt-5-nano');
    expect(sentToModel().max_output_tokens).toBeLessThan(999_999);
  });

  it('is refused when the body is not base64, so nothing can be smuggled into the request', async () => {
    const response = await scan(await signIdToken(key), {
      image: '","model":"gpt-5-pro","x":"',
    });

    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: 'bad_image' });
  });

  it('is refused when the image is larger than a resized receipt could be', async () => {
    const response = await scan(await signIdToken(key), {
      image: 'A'.repeat(700_001),
    });

    expect(response.status).toBe(413);
    expect(await response.json()).toMatchObject({ error: 'image_too_large' });
  });

  it('is a model_unavailable failure when the model itself refuses the request', async () => {
    expectModelCall({ status: 500, body: '{"error":{"message":"boom"}}' });

    const response = await scan(await signIdToken(key, { sub: 'uid-upstream' }));

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({
      error: 'model_unavailable',
      upstream_status: 500,
    });
  });

  it('never mentions the key, whatever goes wrong', async () => {
    expectModelCall({
      status: 401,
      body: '{"error":{"code":"invalid_api_key"}}',
    });

    const response = await scan(await signIdToken(key, { sub: 'uid-quiet' }));

    expect(await response.text()).not.toContain('test-key-not-a-real-one');
  });
});

describe("a user's daily allowance", () => {
  it('runs out with a status of its own, and says when it comes back', async () => {
    expectModelCall({ times: 1 });
    const token = await signIdToken(key, { sub: 'uid-capped' });

    const first = await scan(token, { query: '?cap=1' });
    const second = await scan(token, { query: '?cap=1' });

    expect(first.status).toBe(200);
    expect(second.status).toBe(429);
    expect(await second.json()).toMatchObject({
      error: 'cap_reached',
      used: 1,
      limit: 1,
      resets_at: expect.stringMatching(/T00:00:00\.000Z$/),
    });
  });

  it('is counted per user, so one heavy day does not stop anyone else', async () => {
    expectModelCall({ times: 2 });
    const alice = await signIdToken(key, { sub: 'uid-alice' });
    const bob = await signIdToken(key, { sub: 'uid-bob' });

    expect((await scan(alice, { query: '?cap=1' })).status).toBe(200);
    expect((await scan(alice, { query: '?cap=1' })).status).toBe(429);
    expect((await scan(bob, { query: '?cap=1' })).status).toBe(200);
  });

  it('cannot be raised past the ceiling the deployment sets', async () => {
    expectModelCall({ times: 1 });
    const token = await signIdToken(key, { sub: 'uid-greedy' });

    await scan(token, { query: '?cap=99999' });
    const refused = await scan(token, { query: '?cap=1' });

    expect(refused.status).toBe(429);
    expect(await refused.json()).toMatchObject({ limit: 1 });
  });
});

describe('the Worker', () => {
  it('says it is alive without being asked for a token', async () => {
    const response = await SELF.fetch('https://worker.test/health');

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
  });

  it('has nothing at any other path', async () => {
    const response = await SELF.fetch('https://worker.test/', {
      method: 'POST',
    });

    expect(response.status).toBe(404);
  });

  it('does not read a Scan out of a GET', async () => {
    const response = await SELF.fetch('https://worker.test/extract');

    expect(response.status).toBe(405);
  });

  it('fetched the signing keys once for every Scan above', () => {
    fetchMock.assertNoPendingInterceptors();
  });
});
