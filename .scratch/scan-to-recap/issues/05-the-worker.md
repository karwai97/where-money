# 05 — The Worker, authenticated and capped

**What to build:** A deployed endpoint that turns a receipt image into a model
response, and refuses anyone who isn't a signed-in user of this app or who has
already used their allowance today. Verified with `curl` — no Flutter involved.

The Worker is the only place the OpenAI key exists. It verifies the caller's
Firebase ID token against Google's signing certs, caching them in the isolate so
a Scan doesn't pay for a cert fetch every time. It reads and increments a
per-user daily counter and refuses past the cap with a status distinct from every
other failure, so the app can say "resets tomorrow" rather than "something went
wrong".

**The Worker owns request construction** — the prompt, the schema, and an
allowlist of models. A client cannot name its own model or output budget, because
a modified client that could would be an expensive problem. It returns the raw
model response; the client parses it with the Dart code from ticket 02.

Strict mode constrains the schema in ways that are easy to "fix" wrongly later.
Every object needs `additionalProperties: false`, **every** property must appear
in `required`, and the root cannot use `anyOf` — so optionality is a type union,
not an omitted key. From the prototype, where idiomatic elsewhere would be an
`anyOf` with a null branch and here that is rejected outright:

```jsonc
"subtotal": { "type": ["number", "null"] }
```

The free plan allows 10ms of CPU per request. Waiting on `fetch` is exempt, so the
model round trip is free, but placing a ~270KB base64 string into a request body
is not. Build the body by templating rather than by parsing the incoming request,
and measure it — this is the one performance risk in the ticket.

**Blocked by:** 03

**Status:** ready-for-agent

- [x] Deployed and reachable, with the key set as a Worker secret and present nowhere else
- [x] A request with no token is refused
- [x] A request with a malformed or expired token is refused, distinctly from having no token
- [x] A request with a valid token and a real receipt photo returns a model response that the ticket-02 parser turns into an Extraction with the right merchant and total
- [x] The daily counter increments per user, and the cap returns its own distinct status
- [x] Two different signed-in users have independent counters
- [x] Signing certs are cached across requests within an isolate
- [x] A client-supplied model name is ignored in favour of the allowlist
- [x] CPU time per request is measured and recorded in the ticket, with the templating approach shown to stay inside the limit
- [x] The date-format keyword is confirmed to survive strict mode, or dropped to a plain nullable string
- [x] Whether the nano tier accepts a reasoning-effort parameter is confirmed either way, and the omit path works if it does not

## Comments

Done, deployed, and verified against a real receipt. Live at
`https://where-money.karwai-ngim.workers.dev`. All eleven criteria are ticked;
what follows says which were proved live and which by test, because those are not
the same claim.

`worker/` is TypeScript on Cloudflare, outside the Dart workspace, with
`tools/firestore-rules/` as the precedent for a Node project in this repo. 64
tests run against the local Workers runtime under
`@cloudflare/vitest-pool-workers`, plus 2 core tests and a CPU measurement.
`POST /extract` takes the base64 as the whole body and the knobs as query
parameters; `worker/README.md` is the contract. `GET /health` answers without a
token.

### The live run

A photographed clinic receipt — 1280x963, 77KB, 103,160 characters of base64 —
sent to the deployed Worker with a real Firebase ID token. What came back,
through `parseExtraction` and the Check:

```
merchant: KLINIK MEDILIFE
total: 110.0 MYR
purchasedAt: 2026-08-04
paymentMethod: cash
category: healthcare (Clinic consultation and medication payment.)
lineItems: 0
servedBy: gpt-5-nano-2025-08-07
Check: consistent, no Findings
```

Correct on every field, including reading `04/Aug/2026` as `2026-08-04` — the
misread year that broke the prototype did not happen here. No line items is also
correct: the receipt prices nothing individually, it only says
"Consultation: Medication:". The model set `needs_review` false, and the Check
agreed with it.

One receipt is not a measurement of accuracy. It is a measurement that the
pipeline works.

### CPU per request, from Cloudflare

```
POST /extract   cpu 1ms   wall 4483ms   ok
```

`wrangler tail` against the deployed Worker, for the Scan above. **1ms of the
10ms the free plan allows**, against a 4.5-second wall time that is almost
entirely the model round trip — which is exempt, exactly as ADR-0001 assumed. The
templating approach is not merely inside the limit, it is a tenth of it.

`npm run measure` breaks the same work down in Node, because a Worker's clock
does not advance during synchronous execution and so cannot measure itself:

| | a 1024px receipt (270KB of base64) | the largest body accepted (700KB) |
|---|---|---|
| checking it is base64 | 0.17ms | 0.42ms |
| templating and encoding the body | 0.51ms | 1.25ms |
| **together, per Scan** | **0.68ms** | **1.67ms** |
| parsing it out of a JSON envelope instead | 0.68ms | 1.70ms |

Two honest notes on that table. Templating and parsing measure about the same,
because encoding the outgoing body dominates both and neither approach can skip
it — templating's win is real but small at these sizes. And the accepted limit
was 2,000,000 characters in the first draft, where the same work costs 4.9ms; it
is 700,000 now, which is 2.6x what a Scan actually sends.

### The three unknowns the spec listed

- **The date-format keyword survives strict mode.** The response echoes the
  schema back with `"format": "date"` intact on `purchased_at`. Nothing has to
  drop to a plain nullable string.
- **The nano tier accepts a reasoning-effort parameter.** `effort=low` returns
  200 and the response echoes `"reasoning": {"effort": "low"}` back. `effort=omit`
  also returns 200, so the escape hatch works, but it is not needed.
- **Latency is 4 to 6 seconds** a Scan, across half a dozen calls. Comfortably
  inside what ADR-0004's decoupled Scan was designed to absorb, and far too slow
  to hold a user on a spinner for — which is what ADR-0004 already assumed.

### Cost, now that there are real numbers

2,717 input tokens and around 500 output a Scan, of which **2,688 input tokens
came back cached** on every repeat call — the instructions and the schema are
identical each time, so the API caches them. At the nano tier's rates that is
about **US$0.0003 a Scan**, a third of a cent for ten receipts. The spec's "under
a cent per user per month" was not optimistic.

### What the live run changed

**`"store": false` is now in every request.** The response came back saying
`"store": true`, which is the API's default: it keeps each response, receipt
included, for later retrieval. Nothing here ever reads one back, and the test
receipt carried a name, an NRIC and a phone number. One line, and a test.

`verify-deployed.sh` had a bug the live run exposed: OpenAI sends `"error": null`
on success, so checking for the *presence* of an `error` key printed every
successful scan as a failure.

### What was proved by test rather than live

Three of the ticked criteria, said plainly:

- **An expired token.** Refused as `reason: "expired"` in the unit tests. Live, a
  Firebase token lasts an hour and nobody waited. What *was* proved live is the
  distinction the criterion is actually about: no token is 401 `missing_token`,
  and a token we will not take is 403 `invalid_token` with the reason in the body
  — `malformed` for a non-JWT, `unknown_key` for a JWT signed by nobody.
- **Signing certs cached across requests in an isolate.** Proved by the
  integration tests, which publish the keys exactly once for the whole file and
  would fail everywhere if the cache stopped working. Live, the `unknown_key`
  refusal proves the fetch happens at all; from outside it cannot prove that the
  second request skipped it.
- **The counter being per user** was proved live — two uids, one capped at 1 and
  refused, the other still allowed — but with anonymous Firebase users minted
  over the REST API rather than two Google accounts. The Worker cannot tell the
  difference, same `aud` and same `iss`, but the Google Sign-In path itself is
  still only proved by ticket 03's device run.

Anonymous sign-in was enabled in the Firebase console for that and **must be
turned off again**: while it is on, anyone can mint a token this Worker accepts,
each with its own 40-Scan allowance.

### The cap

The client's requested cap, clamped to `DAILY_SCAN_CEILING`. Ticket 13 wants the
cap changeable from Remote Config with no Worker deploy; the spec wants it
enforced on the server; a client-proposed number under a deployment-owned ceiling
is the only shape that satisfies both. Live sequence at `?cap=2`: 200, 200, then
429 with `used: 2, limit: 2, resets_at: "2026-08-25T00:00:00.000Z"`.

A ceiling that is missing or misspelt falls back to a compiled-in 40 rather than
to no cap at all — the first draft let a bad ceiling parse as `NaN`, which made
every comparison false and quietly allowed everything.

Two things about it are approximate, deliberately:

- **A Scan that fails on its way to the model still spends its allowance.** The
  reservation is taken before the call because the call is what costs. Ticket
  08's automatic retry will therefore eat allowance on a flapping network. If
  that hurts, the fix is a refund on a failed call, not a later reservation.
- **The counter is not exact.** KV reads what it last replicated, so two Scans at
  once, or two Scans in two colos, can read the same number and both be allowed.
  The cap bounds the bill; it is not a quota. An exact counter means a Durable
  Object.

### The token check

Against Google's JWK endpoint rather than the x509 one, so the keys import
straight into WebCrypto with no PEM parsing. Signature, `aud`, `iss`, `exp`,
`iat` and a non-empty `sub`, with a minute of clock skew. Google being
unreachable is **503 `signing_keys_unavailable`**, not a 403 — it is not the
caller's token that is wrong, and telling them to sign in again would be a lie.

Two bugs found in review, both in the caching:

- **An unseen key id used to be refused outright.** Google rotates keys inside the
  window it tells us to cache them for, so a good token could arrive signed by a
  key we had never fetched and be rejected as the caller's fault. A miss now buys
  exactly one re-fetch per set of keys — not one per request, or inventing key ids
  would be a way to make the Worker fetch all day.
- **A response with no `cache-control` was treated as already expired**, which
  meant a cert fetch on every Scan: the exact cost the cache exists to avoid. It
  falls back to an hour.

### Two deliberate additions the ticket did not ask for

`GET /health`, because "deployed and reachable" should not need a token or a
receipt. And `?media=`, allowlisted to jpeg, png and webp, because a photo picked
from the gallery is not necessarily a jpeg and the data URL has to name the type
truthfully. Neither is a knob in the spec's sense; a client cannot use either to
spend more money.

`preview_urls` is off in `wrangler.jsonc`. Each preview URL is another public
endpoint holding the same key and writing the same counters, and with one
deployment and no staging there is nothing for them to be useful for.

### For ticket 06 and 07

The client base64-encodes and sends that as the body, `content-type: text/plain`,
no JSON envelope. That is the CPU constraint, not a preference. Query parameters
carry the knobs: `model`, `effort`, `media`, `cap`.

`ModelGateway` still does not exist. When it appears, the failure taxonomy maps
one-to-one onto the statuses in `worker/README.md`, and `cap_reached` carries
`resets_at` so the Inbox can say when rather than sorry. And at 4 to 6 seconds a
Scan, the thing that calls it wants to be a background job rather than an await
on a screen — which is what ticket 07 already says, now with a number behind it.
