import { fetchMock } from 'cloudflare:test';

export const PROJECT_ID = 'where-money-72ee2';
export const JWK_ORIGIN = 'https://www.googleapis.com';
export const JWK_PATH =
  '/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

export interface SigningKey {
  kid: string;
  privateKey: CryptoKey;
  jwk: JsonWebKey & { kid: string };
}

const algorithm = {
  name: 'RSASSA-PKCS1-v1_5',
  modulusLength: 2048,
  publicExponent: new Uint8Array([1, 0, 1]),
  hash: 'SHA-256',
} as const;

export async function makeSigningKey(kid = 'kid-a'): Promise<SigningKey> {
  const pair = (await crypto.subtle.generateKey(algorithm, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  const jwk = (await crypto.subtle.exportKey(
    'jwk',
    pair.publicKey,
  )) as JsonWebKey;
  return {
    kid,
    privateKey: pair.privateKey,
    jwk: { ...jwk, kid, alg: 'RS256', use: 'sig' },
  };
}

// Stands in for Google's published signing keys. [times] is the assertion:
// the interceptor is consumed once per fetch, so registering one and asking
// vitest for no pending interceptors afterwards says the isolate fetched the
// keys exactly once however many requests it served.
export function publishSigningKeys(
  keys: SigningKey[],
  {
    times = 1,
    maxAge = 3600,
  }: { times?: number; maxAge?: number | null } = {},
): void {
  fetchMock
    .get(JWK_ORIGIN)
    .intercept({ path: JWK_PATH, method: 'GET' })
    .reply(200, JSON.stringify({ keys: keys.map((k) => k.jwk) }), {
      headers: {
        'content-type': 'application/json',
        // null publishes them with no cache-control at all, which is Google
        // going quiet about how long they are good for.
        ...(maxAge === null
          ? {}
          : { 'cache-control': `public, max-age=${maxAge}` }),
      },
    })
    .times(times);
}

export function refuseSigningKeys(): void {
  fetchMock
    .get(JWK_ORIGIN)
    .intercept({ path: JWK_PATH, method: 'GET' })
    .reply(500, 'upstream is having a day');
}

export interface Claims {
  iss?: string;
  aud?: string;
  sub?: string;
  iat?: number;
  exp?: number;
  auth_time?: number;
}

export async function signIdToken(
  key: SigningKey,
  claims: Claims = {},
  header: Record<string, unknown> = {},
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT_ID}`,
    aud: PROJECT_ID,
    sub: 'uid-alice',
    iat: now - 60,
    exp: now + 3600,
    auth_time: now - 60,
    ...claims,
  };
  const signingInput = `${b64url(
    JSON.stringify({ alg: 'RS256', kid: key.kid, typ: 'JWT', ...header }),
  )}.${b64url(JSON.stringify(payload))}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key.privateKey,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${b64urlBytes(new Uint8Array(signature))}`;
}

// A token whose signature is a valid one from the wrong key, so it fails at
// the signature rather than at the shape.
export async function signWithWrongKey(
  advertisedKid: string,
  other: SigningKey,
  claims: Claims = {},
): Promise<string> {
  return signIdToken(other, claims, { kid: advertisedKid });
}

export function b64url(text: string): string {
  return b64urlBytes(new TextEncoder().encode(text));
}

export function b64urlBytes(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
