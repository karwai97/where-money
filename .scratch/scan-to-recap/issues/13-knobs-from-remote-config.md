# 13 — Knobs from Remote Config

**What to build:** The model tier can be changed from a console and the next Scan
uses it — no app update, no store review, no deploy. Same for the image size, the
reasoning effort, and the daily cap.

This is the ticket that makes the project's one open question actionable. Whether
the cheapest vision-capable model is accurate enough is unmeasured; the corrected
fields tally from tickets 04 and 07 is what answers it. When that tally says the
total or the merchant is being misread, the fix has to be minutes rather than a
release cycle — otherwise the instrumentation is just data nobody acts on.

The knobs are behaviour, not secrets. Values delivered by Remote Config are
readable by anyone with the app, which is fine for a model name and would be
disqualifying for a key — the key stays a Worker secret. Compiled-in defaults mean
a fetch failure or a first launch with no network behaves correctly rather than
not at all.

**Blocked by:** 05, 07

**Status:** ready-for-agent

- [ ] Model tier, image long edge, reasoning effort and the daily cap all come from Remote Config
- [ ] Compiled-in defaults are used when a fetch fails or has not completed
- [ ] Changing the tier in the console changes what the next Scan uses, with no rebuild
- [ ] The requested model is still checked against the Worker's allowlist, so an unknown value cannot reach the API
- [ ] Changing the cap takes effect without a Worker deploy
- [ ] Knobs are passed through the app as plain values, not injected as a collaborator, and tests set them directly
- [ ] The current knob values are visible somewhere in the app, so a misconfiguration is diagnosable
- [ ] No secret is ever read from Remote Config
