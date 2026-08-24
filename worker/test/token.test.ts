import { env } from 'cloudflare:test';
import { fetchMock } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { SigningKeys, verifyIdToken } from '../src/token';
import {
  makeSigningKey,
  PROJECT_ID,
  publishSigningKeys,
  refuseSigningKeys,
  signIdToken,
  signWithWrongKey,
} from './support';

describe('a Firebase ID token', () => {
  let keys: SigningKeys;
  const verify = (token: string) => verifyIdToken(token, PROJECT_ID, keys);

  beforeEach(() => {
    keys = new SigningKeys();
  });

  // Each test publishes exactly the key fetches it expects to be made.
  afterEach(() => fetchMock.assertNoPendingInterceptors());

  it('names the caller when it is signed by a published key', async () => {
    const key = await makeSigningKey();
    publishSigningKeys([key]);

    expect(await verify(await signIdToken(key, { sub: 'uid-alice' }))).toEqual({
      ok: true,
      uid: 'uid-alice',
    });
  });

  it('is refused when it has expired', async () => {
    const key = await makeSigningKey();
    publishSigningKeys([key]);
    const past = Math.floor(Date.now() / 1000) - 7200;

    expect(
      await verify(await signIdToken(key, { iat: past, exp: past + 3600 })),
    ).toEqual({ ok: false, reason: 'expired' });
  });

  it('is refused when it was signed by a key Google does not publish', async () => {
    const published = await makeSigningKey('kid-a');
    const impostor = await makeSigningKey('kid-a');
    publishSigningKeys([published]);

    expect(await verify(await signWithWrongKey('kid-a', impostor))).toEqual({
      ok: false,
      reason: 'bad_signature',
    });
  });

  it('is refused when its key id is not one of the published ones', async () => {
    const key = await makeSigningKey('kid-a');
    publishSigningKeys([key]);

    expect(
      await verify(await signIdToken(key, {}, { kid: 'kid-nobody-has' })),
    ).toEqual({ ok: false, reason: 'unknown_key' });
  });

  it('is refused when it was minted for another Firebase project', async () => {
    const key = await makeSigningKey();
    publishSigningKeys([key]);

    expect(
      await verify(await signIdToken(key, { aud: 'someone-elses-project' })),
    ).toEqual({ ok: false, reason: 'wrong_audience' });
  });

  it('is refused when it was not issued by Google', async () => {
    const key = await makeSigningKey();
    publishSigningKeys([key]);

    expect(
      await verify(
        await signIdToken(key, {
          iss: `https://evil.example/${PROJECT_ID}`,
        }),
      ),
    ).toEqual({ ok: false, reason: 'wrong_issuer' });
  });

  it('is refused when it names no user', async () => {
    const key = await makeSigningKey();
    publishSigningKeys([key]);

    expect(await verify(await signIdToken(key, { sub: '' }))).toEqual({
      ok: false,
      reason: 'no_subject',
    });
  });

  it('is refused when it is not a JWT at all, without fetching any keys', async () => {
    expect(await verify('nonsense')).toEqual({
      ok: false,
      reason: 'malformed',
    });
  });

  it('is refused when it asks to be checked with an algorithm we do not accept', async () => {
    const key = await makeSigningKey();

    expect(await verify(await signIdToken(key, {}, { alg: 'none' }))).toEqual({
      ok: false,
      reason: 'unsupported_alg',
    });
  });

  it('is neither accepted nor blamed when the keys cannot be fetched', async () => {
    const key = await makeSigningKey();
    refuseSigningKeys();

    expect(await verify(await signIdToken(key))).toEqual({
      ok: false,
      reason: 'keys_unavailable',
      ours: true,
    });
  });

  it('is checked against keys fetched once and then reused', async () => {
    const key = await makeSigningKey('kid-cached');
    publishSigningKeys([key], { times: 1 });

    const first = await verify(await signIdToken(key, { sub: 'uid-alice' }));
    const second = await verify(await signIdToken(key, { sub: 'uid-bob' }));

    expect([first, second]).toEqual([
      { ok: true, uid: 'uid-alice' },
      { ok: true, uid: 'uid-bob' },
    ]);
  });

  it('is checked against a re-fetch once the published keys have gone stale', async () => {
    const key = await makeSigningKey('kid-brief');
    publishSigningKeys([key], { maxAge: 0 });
    publishSigningKeys([key], { maxAge: 3600 });

    expect(await verify(await signIdToken(key))).toEqual({
      ok: true,
      uid: 'uid-alice',
    });
    expect(await verify(await signIdToken(key))).toEqual({
      ok: true,
      uid: 'uid-alice',
    });
  });
});

it('reads the Firebase project id from the deployment rather than a constant', () => {
  expect(env.FIREBASE_PROJECT_ID).toBe(PROJECT_ID);
});
