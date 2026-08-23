---
status: accepted
---

# The Model is called through a Cloudflare Worker, not from the app

The OpenAI key cannot ship in the client — the prototype verified that a
`--dart-define` key is greppable out of `kernel_blob.bin`, and Firebase Remote
Config is worse still, since its values are readable over the REST API using the
public app ID in `google-services.json`. The obvious home for a proxy is Cloud
Functions, but outbound network access to non-Google hosts requires the Blaze
plan and we are staying on Spark with no card on file. So the proxy is a
Cloudflare Worker: free with no payment method, and the key lives in a Worker
secret.

## Consequences

- Availability now depends on Cloudflare in addition to OpenAI.
- The Worker's free plan allows 10ms of CPU per request. Waiting on `fetch` is
  exempt, so the OpenAI round trip is free, but touching the image is not:
  **the client base64-encodes and the Worker forwards the body unparsed.**
- Google's JWT signing certs must be cached in the isolate, or every Scan pays
  an extra subrequest.
- Unlike Cloud Functions, there is no cold start to design around — isolates
  start in single-digit milliseconds against Node's 1.2–2.8s p95.
- Firebase Storage is unavailable for the same billing reason, which is why
  receipt images are device-local (see ADR-0003).
