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
- [ ] A request with no token is refused
- [ ] A request with a malformed or expired token is refused, distinctly from having no token
- [ ] A request with a valid token and a real receipt photo returns a model response that the ticket-02 parser turns into an Extraction with the right merchant and total
- [ ] The daily counter increments per user, and the cap returns its own distinct status
- [ ] Two different signed-in users have independent counters
- [ ] Signing certs are cached across requests within an isolate
- [ ] A client-supplied model name is ignored in favour of the allowlist
- [ ] CPU time per request is measured and recorded in the ticket, with the templating approach shown to stay inside the limit
- [ ] The date-format keyword is confirmed to survive strict mode, or dropped to a plain nullable string
- [ ] Whether the nano tier accepts a reasoning-effort parameter is confirmed either way, and the omit path works if it does not
