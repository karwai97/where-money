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

- [ ] Deployed and reachable, with the key set as a Worker secret and present nowhere else
- [x] A request with no token is refused
- [x] A request with a malformed or expired token is refused, distinctly from having no token
- [ ] A request with a valid token and a real receipt photo returns a model response that the ticket-02 parser turns into an Extraction with the right merchant and total
- [x] The daily counter increments per user, and the cap returns its own distinct status
- [x] Two different signed-in users have independent counters
- [x] Signing certs are cached across requests within an isolate
- [x] A client-supplied model name is ignored in favour of the allowlist
- [x] CPU time per request is measured and recorded in the ticket, with the templating approach shown to stay inside the limit
- [ ] The date-format keyword is confirmed to survive strict mode, or dropped to a plain nullable string
- [ ] Whether the nano tier accepts a reasoning-effort parameter is confirmed either way, and the omit path works if it does not

## Comments

Built and tested; **not deployed**, and four criteria are unticked because of
that. `worker/` is TypeScript on Cloudflare, outside the Dart workspace, with
`tools/firestore-rules/` as the precedent for a Node project living in this repo.
63 tests run against the local Workers runtime under
`@cloudflare/vitest-pool-workers`, plus 2 core tests and a CPU measurement.

`POST /extract` takes the base64 as the whole body and the knobs as query
parameters. `worker/README.md` is the contract. `GET /health` answers without a
token, which is how "deployed and reachable" gets checked in one curl.

### What is not done, and why

Deploying needs a Cloudflare account, a KV namespace and the key as a secret.
None of those exist in this environment and none of them are an agent's to
create, so:

- **Nothing is deployed**, and the key criterion stays unticked. The key appears
  nowhere in this repo; `worker/.dev.vars` is gitignored and `.dev.vars.example`
  is what is committed.
- **No live model call has been made**, so the date-format keyword surviving
  strict mode and whether the nano tier accepts `reasoning.effort` are both
  still unknown. Both are one request away and both have somewhere to land: the
  format keyword drops to a plain nullable string, and `?effort=omit` leaves the
  key out entirely (tested).
- **The end-to-end criterion is half done.** What is proved is that the response
  the Worker returns is the response ticket 02's parser reads: the Worker returns
  the upstream body byte for byte, and
  `packages/core/test/worker_wire_test.dart` and `worker/test/extract.test.ts`
  both read `worker/test/fixtures/model-response.json`, so the Worker's output
  shape and the Dart parser cannot drift apart alone. What is not proved is that
  a real photograph produces that shape.

`worker/verify-deployed.sh` walks every one of those, given a URL, a receipt and
two ID tokens. It is the handover for the parts only a human with an account can
do.

### CPU per request, measured

`npm run measure`, in Node — inside a Worker the clock does not advance during
synchronous execution, so the runtime cannot time itself. Same V8, same string
operations.

| | a 1024px receipt (270KB of base64) | the largest body accepted (700KB) |
|---|---|---|
| checking it is base64 | 0.17ms | 0.42ms |
| templating and encoding the body | 0.51ms | 1.25ms |
| **together, per Scan** | **0.68ms** | **1.67ms** |
| parsing it out of a JSON envelope instead | 0.68ms | 1.70ms |

Comfortably inside 10ms, which is what the ticket asked for. Two honest notes on
the numbers. First, templating and parsing measure almost the same, because
encoding the outgoing body to bytes dominates both and neither approach can skip
it — templating's win over parsing is real but small at these sizes, and the
figure that matters is that the worst case is under a fifth of the budget.
Second, the ticket's ~270KB is what the app sends but not what the endpoint
accepts, so the limit was set to 700,000 characters and measured there too. It
was 2,000,000 in the first draft, where the same work costs 4.9ms — half the
budget for an image no Scan should ever send.

### The cap

It is the client's requested cap clamped to `DAILY_SCAN_CEILING`. Ticket 13 wants
the cap changeable from Remote Config without a Worker deploy, and the spec wants
it enforced on the server; a client-proposed number under a deployment-owned
ceiling is the only shape that satisfies both. Nothing a modified client sends
can raise it, and a ceiling that is missing or misspelt in `wrangler.jsonc` falls
back to a compiled-in 40 rather than to no cap at all — the first draft let a
bad ceiling parse as `NaN`, which made every comparison false and quietly
allowed everything.

Two things about it are approximate, deliberately:

- **A Scan that fails on its way to the model still spends its allowance.** The
  reservation is taken before the call because the call is what costs. Ticket
  08's automatic retry will therefore eat allowance on a flapping network. If
  that turns out to hurt, the fix is a refund on a failed call, not a later
  reservation.
- **The counter is not exact.** KV reads what it last replicated, so two Scans at
  once, or two Scans in two colos, can read the same number and both be allowed.
  The cap bounds the bill; it is not a quota. The spec chose KV, and an exact
  counter means a Durable Object.

### The token check

Verified against Google's JWK endpoint rather than the x509 one, so the keys
import straight into WebCrypto with no PEM parsing. Signature, `aud`, `iss`,
`exp`, `iat` and a non-empty `sub`, with a minute of clock skew; each refusal has
its own reason, and the reason travels in the 403 body.

Google being unreachable is **503 `signing_keys_unavailable`**, not a 403. It is
not the caller's token that is wrong, and telling them to sign in again would be
a lie.

Two bugs found in review, both in the caching:

- **An unseen key id used to be refused outright.** Google rotates keys inside
  the window it tells us to cache them for, so a perfectly good token could
  arrive signed by a key we had never fetched and be rejected as the caller's
  fault. A miss now buys exactly one re-fetch per set of keys — not one per
  request, or inventing key ids would be a way to make the Worker fetch all day.
- **A response with no `cache-control` was treated as already expired**, which
  would have meant a cert fetch on every single Scan: the exact cost the cache
  exists to avoid. It now falls back to an hour.

### Two deliberate additions the ticket did not ask for

`GET /health`, because "deployed and reachable" should not require a token or a
receipt. And `?media=`, allowlisted to jpeg, png and webp, because a photo chosen
from the gallery is not necessarily a jpeg and the data URL has to name the type
truthfully. Neither is a knob in the spec's sense; the client cannot use either
to spend more money.

### For ticket 06 and 07

The client base64-encodes and sends that as the body, with
`content-type: text/plain` and no JSON envelope. That is not a preference, it is
the CPU constraint — a 270KB string inside a JSON body would have to be parsed
out of it. Query parameters carry the knobs: `model`, `effort`, `media`, `cap`.

`ModelGateway` still does not exist. When it appears, the failure taxonomy it
needs maps one-to-one onto the statuses in `worker/README.md`, and `cap_reached`
carries `resets_at` so the Inbox can say when rather than sorry.
