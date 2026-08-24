// Checking that the caller is a signed-in user of this app.
//
// A Firebase ID token is an RS256 JWT signed by Google, so the check needs
// Google's published signing keys. Fetching them is a subrequest, and a Scan
// that pays for one every time is a Scan that got slower for nothing — so an
// isolate fetches them once and reuses them until they expire.

const jwkUrl =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const clockSkewSeconds = 60;

export type TokenRefusal =
  | 'malformed'
  | 'unsupported_alg'
  | 'unknown_key'
  | 'bad_signature'
  | 'expired'
  | 'not_yet_valid'
  | 'wrong_audience'
  | 'wrong_issuer'
  | 'no_subject'
  | 'keys_unavailable';

export type TokenOutcome =
  | { ok: true; uid: string }
  // `ours` marks a refusal that is not the caller's fault, so the caller is
  // told to come back rather than told to sign in again.
  | { ok: false; reason: TokenRefusal; ours?: true };

type Lookup =
  | { ok: true; key: CryptoKey }
  | { ok: false; reason: 'unknown_key' | 'keys_unavailable' };

export class SigningKeys {
  #keys = new Map<string, CryptoKey>();
  #expiresAt = 0;
  #inFlight: Promise<boolean> | null = null;

  async lookup(kid: string): Promise<Lookup> {
    if (Date.now() >= this.#expiresAt && !(await this.#refresh())) {
      return { ok: false, reason: 'keys_unavailable' };
    }
    const key = this.#keys.get(kid);
    return key ? { ok: true, key } : { ok: false, reason: 'unknown_key' };
  }

  #refresh(): Promise<boolean> {
    this.#inFlight ??= this.#fetchKeys().finally(() => {
      this.#inFlight = null;
    });
    return this.#inFlight;
  }

  async #fetchKeys(): Promise<boolean> {
    let response: Response;
    try {
      response = await fetch(jwkUrl);
    } catch {
      return false;
    }
    if (!response.ok) return false;

    let published: { keys?: unknown };
    try {
      published = (await response.json()) as { keys?: unknown };
    } catch {
      return false;
    }
    if (!Array.isArray(published.keys)) return false;

    const imported = new Map<string, CryptoKey>();
    for (const entry of published.keys) {
      const jwk = entry as Record<string, unknown>;
      if (typeof jwk.kid !== 'string' || jwk.kty !== 'RSA') continue;
      try {
        imported.set(
          jwk.kid,
          await crypto.subtle.importKey(
            'jwk',
            { kty: 'RSA', n: jwk.n as string, e: jwk.e as string, alg: 'RS256' },
            { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
            false,
            ['verify'],
          ),
        );
      } catch {
        continue;
      }
    }
    if (imported.size === 0) return false;

    this.#keys = imported;
    this.#expiresAt = Date.now() + maxAgeMillis(response.headers.get('cache-control'));
    return true;
  }
}

// Isolate-lifetime, which is the whole point: the second Scan an isolate serves
// pays no subrequest for the keys.
export const signingKeys = new SigningKeys();

export async function verifyIdToken(
  token: string,
  projectId: string,
  keys: SigningKeys = signingKeys,
): Promise<TokenOutcome> {
  const parts = token.split('.');
  if (parts.length !== 3) return { ok: false, reason: 'malformed' };
  const [rawHeader, rawPayload, rawSignature] = parts as [string, string, string];

  const header = decodeSegment(rawHeader);
  const payload = decodeSegment(rawPayload);
  if (!header || !payload) return { ok: false, reason: 'malformed' };
  if (header.alg !== 'RS256') return { ok: false, reason: 'unsupported_alg' };
  if (typeof header.kid !== 'string') return { ok: false, reason: 'malformed' };

  const lookup = await keys.lookup(header.kid);
  if (!lookup.ok) {
    return lookup.reason === 'keys_unavailable'
      ? { ok: false, reason: 'keys_unavailable', ours: true }
      : { ok: false, reason: 'unknown_key' };
  }

  const signature = decodeBytes(rawSignature);
  if (!signature) return { ok: false, reason: 'malformed' };
  const signed = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    lookup.key,
    signature,
    new TextEncoder().encode(`${rawHeader}.${rawPayload}`),
  );
  if (!signed) return { ok: false, reason: 'bad_signature' };

  const now = Math.floor(Date.now() / 1000);
  if (!isNumber(payload.exp) || payload.exp <= now - clockSkewSeconds) {
    return { ok: false, reason: 'expired' };
  }
  if (!isNumber(payload.iat) || payload.iat > now + clockSkewSeconds) {
    return { ok: false, reason: 'not_yet_valid' };
  }
  if (payload.aud !== projectId) return { ok: false, reason: 'wrong_audience' };
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    return { ok: false, reason: 'wrong_issuer' };
  }
  if (typeof payload.sub !== 'string' || payload.sub === '') {
    return { ok: false, reason: 'no_subject' };
  }

  return { ok: true, uid: payload.sub };
}

function decodeSegment(segment: string): Record<string, unknown> | null {
  const bytes = decodeBytes(segment);
  if (!bytes) return null;
  try {
    const parsed: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return parsed !== null && typeof parsed === 'object'
      ? (parsed as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

function decodeBytes(segment: string): Uint8Array | null {
  try {
    const binary = atob(segment.replace(/-/g, '+').replace(/_/g, '/'));
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

function maxAgeMillis(cacheControl: string | null): number {
  const match = /max-age=(\d+)/.exec(cacheControl ?? '');
  return match ? Number(match[1]) * 1000 : 0;
}

function isNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}
