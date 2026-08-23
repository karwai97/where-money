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

- [x] The clean fixture passes every Check with no Findings
- [x] The flawed fixture produces Findings for line items not summing to the subtotal, and for an illegible date
- [x] A receipt whose subtotal plus tax plus tip does not reach the total is flagged
- [x] A line whose quantity times unit price does not equal its amount is flagged
- [x] A future date is a failure, not a warning
- [x] A date one year ago produces the year-misread Finding specifically, naming the likely correct year
- [x] A category or payment method outside the taxonomy is caught
- [x] Parsing handles reasoning items appearing before the message, a refusal block, an incomplete status with no text, and well-formed output — each mapping to a distinct outcome
- [x] The Rollup produces category totals, month-over-month deltas, top purchases and the heaviest day
- [x] The Rollup excludes non-Home-Currency Expenses and reports how many it excluded
- [x] The cost maths reproduces the prototype's known-good numbers, including the patch-budget saturation at roughly 1440px
- [x] Every test asserts on Findings, states or numbers — never on call counts or private methods

## Comments

Implemented. Everything lives in `packages/core/lib/src/` behind one export in
`where_money_core.dart`, and it is all pure Dart — 56 tests under `dart test`,
no Flutter harness.

Renamed on the way over, to CONTEXT.md's vocabulary: `ExtractedReceipt` became
`Extraction`, `CheckFinding` became `Finding`, `MonthRollup` became `Rollup`,
and `OpenAiModel` became `ModelTier` (the domain has Models, not AIs).

Four things were changed rather than lifted, and one thing in CONTEXT.md moved
to match.

**A future date is now a failure.** The prototype warned; the ticket asks for a
failure, and it is right — a date that has not happened yet is not a receipt
date, so there is nothing to weigh up.

**A clean Extraction produces no Findings at all**, rather than the prototype's
synthetic "Consistent" ok Finding. That was a UI affordance dressed as a
domain object. `Severity` is now `warn`/`fail`, and CONTEXT.md's Finding entry
was updated to say so instead of leaving a dead enum value behind.

**The misread-year heuristic now survives January.** The prototype tested
`date.year == now.year - 1`, so a December receipt read in January fell into the
generic "unusually old" branch — exactly the case the heuristic exists for. It
now measures the distance in months and asks whether it is within one of
twelve, and there is a test at that boundary.

**`Expense.fromExtraction` was committing failures without flagging them.** The
prototype set `needsReview` from `hasWarning` alone, so an Extraction whose
subtotal plus tax missed the total — a `fail` with no warnings — went into the
Ledger looking reviewed. It is now `!isConsistent`.

Two smaller calls. Only the two tiers the spec names are here; the 5.4 tiers,
the `all` list and `imageCostPerThousand` went, since the Worker owns the model
allowlist and nothing needed them. And parsing has one sealed hierarchy,
`ExtractionOutcome`, not two — a first pass had a wire-level `ModelResponse`
mirrored case-for-case by an extraction-level outcome, which was the same four
cases written twice. When ticket 10 needs the text path for Recaps it can lift
the envelope walk back out.

Category stays a `String` rather than becoming a value type, deliberately: the
Model can return anything, and "a category outside the taxonomy is caught" is
only testable behaviour if an out-of-taxonomy value is representable in the
first place.

Left for later tickets, both noted here so they are not surprises: the Rollup
has no `toJson`, so the Recap payload of ticket 10 does not exist yet, and the
JSON Schema is not here at all — it is ticket 05's, in TypeScript, in the
Worker.
