# 02 — Lift the core domain

**What to build:** The parts of the prototype that were written to survive, moved
into the core package with real tests. Nothing is on screen; this ticket is
verified entirely by its test suite, and it is the ticket that makes every later
one cheap.

Lifted close to unchanged: the domain types, the Check, the Rollup, the Category
and payment-method taxonomies, the vision and cost maths, and the two canned
fixtures — one clean receipt, one deliberately flawed — which become the backbone
of the test suite.

Also lifted, and the most valuable piece: the **response parsing**. The Worker
will own request construction, but parsing stays here, because the traps are what
was hard-won. The response's output array interleaves reasoning items with
message items, so the text is never simply the first element and every message's
content must be walked. A refusal arrives as a refusal content block with a 200
status and must be checked for before any text is trusted. If reasoning consumes
the whole output budget, the status is incomplete with no text at all — a
different failure from truncated JSON, and it needs its own outcome.

The Check keeps its behavioural heuristics, not only its arithmetic. From the
prototype: a date more than 60 days old is flagged, and a date within a month of
exactly one year ago says so explicitly, because on a freshly photographed
receipt that is far more likely a digit error than a genuinely old receipt.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] The clean fixture passes every Check with no Findings
- [ ] The flawed fixture produces Findings for line items not summing to the subtotal, and for an illegible date
- [ ] A receipt whose subtotal plus tax plus tip does not reach the total is flagged
- [ ] A line whose quantity times unit price does not equal its amount is flagged
- [ ] A future date is a failure, not a warning
- [ ] A date one year ago produces the year-misread Finding specifically, naming the likely correct year
- [ ] A category or payment method outside the taxonomy is caught
- [ ] Parsing handles reasoning items appearing before the message, a refusal block, an incomplete status with no text, and well-formed output — each mapping to a distinct outcome
- [ ] The Rollup produces category totals, month-over-month deltas, top purchases and the heaviest day
- [ ] The Rollup excludes non-Home-Currency Expenses and reports how many it excluded
- [ ] The cost maths reproduces the prototype's known-good numbers, including the patch-budget saturation at roughly 1440px
- [ ] Every test asserts on Findings, states or numbers — never on call counts or private methods
