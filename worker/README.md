# The Worker

The only place the OpenAI key exists. TypeScript on Cloudflare, not part of the
Dart workspace — see `docs/adr/0001-cloudflare-worker-proxy.md` for why the
proxy is not on Firebase with everything else.

It does three things: check that the caller is a signed-in user of this app,
check that they have not already used today's allowance, and call the model with
a request the client does not get to shape. Two endpoints stand behind that —
one turns a photographed receipt into an Extraction, the other turns a month's
Rollup into prose.

## The contract

`POST /extract`

| | |
|---|---|
| `Authorization` | `Bearer <Firebase ID token>` |
| Body | the base64 of the image, and nothing else |
| `?model=` | `gpt-5-nano` (default) or `gpt-5-mini`; anything else is ignored |
| `?effort=` | `omit`, `none`, `minimal`, `low` (default), `medium`, `high` |
| `?media=` | `image/jpeg` (default), `image/png`, `image/webp` |
| `?cap=` | today's cap, clamped to the deployment's `DAILY_MODEL_CEILING` |
| `?lang=` | one of the codes in `src/language.ts` (`en` by default); anything else is read as `en` |

The body is the base64 and nothing else because the free plan allows 10ms of CPU
per request. Taking a ~270KB string out of a JSON envelope and serialising it
into another one is the only thing here big enough to matter, so the outgoing
body is templated around the incoming one instead. `npm run measure` prints what
that costs.

`POST /recap`

| | |
|---|---|
| `Authorization` | `Bearer <Firebase ID token>` |
| Body | the Rollup as JSON, at most 10,000 characters |
| `?model=`, `?effort=`, `?cap=`, `?lang=` | as above; `?media=` means nothing here |

The Rollup is the whole prompt: about 1,600 characters whatever the Ledger
under it weighs, and no Expense the Rollup does not already single out. No
schema — what comes back is prose, which is what the screen wants.

`?lang=` says which language the Model writes its own words in: the whole of a
Recap, and an Extraction's `category_reason` and `review_reasons`. What is
transcribed off a receipt is never translated. The instruction itself is the
Worker's — a client sends a code and never prompt text — and a language the
Worker does not know falls back to English rather than being refused, so a
client running ahead of a deploy degrades instead of breaking.

Scans and Recaps are counted against **separate daily counters under the same
ceiling** — `src/allowance.ts` says why.

The prompt, the schema and the output budget are the Worker's. A client that
could name its own model and its own output budget would be an expensive
problem.

On success the model's response is returned exactly as it arrived, for the app
to parse in Dart. On failure the body is `{"error": ..., "message": ...}`:

| Status | `error` | Means |
|---|---|---|
| 401 | `missing_token` | No `Authorization` header |
| 403 | `invalid_token` | A token we will not accept; `reason` says which way |
| 503 | `signing_keys_unavailable` | Google's signing keys were unreachable — ours, not the caller's |
| 400 | `bad_image` | The body was not base64 |
| 413 | `image_too_large` | Over 700,000 characters of base64 |
| 400 | `bad_rollup` | `/recap` was sent something that is not a JSON object |
| 413 | `rollup_too_large` | Over 10,000 characters of Rollup |
| 429 | `cap_reached` | Today's allowance for that endpoint is used up; `resets_at` says when it is not |
| 502 | `model_unavailable` | The model could not be reached or refused the request |

Every answer the allowance was checked for — the 200, the `cap_reached`
refusal, and a `model_unavailable` that got that far — carries how much of the
day is gone:

| Header | Means |
|---|---|
| `x-allowance-used` | Scans (or Recaps) spent today, including this one |
| `x-allowance-limit` | The cap actually enforced, after the ceiling clamps what the client asked for |
| `x-allowance-resets-at` | ISO 8601, when the counter goes back to zero |

The counter is approximate by design — `src/allowance.ts` says why — so these
are what the Worker last saw rather than an exact quota. A refusal made before
the allowance was checked carries none of them.

`GET /health` answers without a token, so "is it deployed" is one curl.

## Running the tests

```
npm install
npm test        # against the local Workers runtime; nothing reaches the network
npm run measure # the CPU measurement, in Node
npm run typecheck
```

The tests intercept both Google's signing keys and the model. They sign real
RS256 tokens with a generated key, so the token checking is exercised rather
than stubbed.

## Deploying

The account, the key and the deploy are yours to do — an agent cannot.

```
npx wrangler login
npx wrangler kv namespace create MODEL_ALLOWANCE  # put the id in wrangler.jsonc
npx wrangler secret put OPENAI_API_KEY            # paste the key; it lives only here
npx wrangler deploy
```

For `wrangler dev`, put the key in `worker/.dev.vars` (gitignored) — see
`.dev.vars.example`. After changing `wrangler.jsonc`, rerun `npx wrangler types`.

`FIREBASE_PROJECT_ID` in `wrangler.jsonc` is what ID tokens are checked against.
It is not a secret; the key is the only secret and it is never in this repo, in
Remote Config, or in a build-time define.

Then verify the deployment against the ticket's criteria:

```
./verify-deployed.sh https://where-money.<subdomain>.workers.dev receipt.jpg
```

It wants two Firebase ID tokens for two different users, which is what makes the
independent-counter check real. `ID_TOKEN` and `SECOND_ID_TOKEN` in the
environment, or it will ask.
