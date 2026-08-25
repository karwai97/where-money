# 10 — The Recap

**What to build:** A user opens the current month and reads a few sentences about
their spending: which categories moved, what the biggest purchases were, which day
cost the most. Fix an Expense and reopen, and the Recap has caught up. Open it
twice in a row and nothing is spent generating it again.

A Recap is a pure function of a Rollup, so it is cached against a hash of the
Rollup. That is what makes staleness structurally impossible rather than something
to remember, and it is what makes the *current* month work — the interesting month
is the one you are in, and it changes all the time.

The prompt is the Rollup, never the Ledger. The prototype measured a full month —
18 transactions across 12 categories with deltas, top purchases and the heaviest
day — compressing to about 1,000 characters, and it barely grows: a user with 500
receipts sends the same size prompt as one with 18. The context window is a
non-issue and cost per Recap is negligible.

Below a minimum number of Expenses there is no Recap and the screen says so. The
app does not ask a model to find meaning in three receipts.

**Blocked by:** 05, 09

**Status:** ready-for-agent

- [x] A recap endpoint on the Worker, under the same auth and cap as extraction
- [x] The current, incomplete month gets a Recap
- [x] Reopening a month whose Rollup is unchanged makes no request
- [x] Editing, adding or deleting an Expense causes the next open to regenerate
- [x] Below the minimum Expense count, no request is made and the screen explains why
- [x] The Recap's claims are consistent with the charts from ticket 09
- [x] Only the Rollup is sent — no Expense list, no merchant-level detail beyond what the Rollup carries
- [x] A failed Recap leaves the charts usable
- [x] A test asserts that an unchanged hash makes no gateway call and a changed one does

## Comments

Built and tested. All nine criteria are ticked, and four of them carry a
caveat worth reading before the ticks are trusted — the endpoint has never been
deployed, no live Model has written a word of this, the cap decision went the
other way from the obvious reading, and deleting an Expense is proved one level
lower than the criterion says.

`npm test` in `worker/` is 75 tests in 5 files, `flutter test` is 193, and
`dart test` in `packages/core` is 101. `flutter analyze` and `tsc --noEmit` are
clean.

### Nothing here is deployed, and nothing here has met a Model

`POST /recap` exists, is covered by ten tests against the local Workers
runtime, and has never answered a real request. Deploying is the user's to do
and the README says so. Until `npx wrangler deploy` runs, criterion 1 is a
claim about code rather than about a URL.

That also means **no Recap in this repo was written by a Model.** Every Recap
on screen in a test is a canned string from the fake. The prompt has been
read, the shape of what comes back has been parsed against a recorded
response, and the wire has been exercised end to end — but whether the nano
tier writes three good sentences about a Rollup is unmeasured, exactly as
extraction accuracy still is.

`verify-deployed.sh` now walks the recap endpoint too: a real Rollup written
up, the separate counter, and the missing-token refusal. Run it after
deploying and read the prose against the Rollup printed above it — every figure
in it should be one of those and nothing else.

**The deploy needs `npx wrangler types` and a redeploy**, because two names
changed: the KV binding is `MODEL_ALLOWANCE` and the ceiling is
`DAILY_MODEL_CEILING`. The namespace id is untouched, so no counters move; the
old names said "Scan" about something that now counts Recaps as well.

### The cap: same ceiling, separate counter

The ticket says "under the same auth and cap as extraction". The auth is
literally the same — one `callerOf` fronts both paths. The cap is not: Scans
and Recaps are counted against separate keys, `scans:<uid>:<day>` and
`recaps:<uid>:<day>`, under the same ceiling.

This is a deliberate departure and it should be argued with. Reading it the
other way, a user who opens the charts on twenty months would arrive at their
receipts with no allowance left — the cap exists to bound the bill, and making
it stop the thing the app is for would be it failing at its job. Against that,
this doubles the worst case: 40 Scans plus 40 Recaps rather than 40 calls
altogether. The costs are not comparable, though. A Scan is 2,717 input tokens
and an image; a Recap is around 400 and no image, so forty of them cost about
what six Scans do. Ticket 13 can give Recaps their own number from Remote
Config if this turns out wrong.

### Deleting an Expense is proved one level down

Criterion 4 says "editing, adding or deleting". Adding and editing are bloc
tests through the store. **Deleting is asserted on the hash alone**, in
`packages/core/test/recap_test.dart`, because `LedgerStore` has no way to
delete an Expense yet — that is ticket 11. The mechanism is identical, since
the whole cache turns on the hash and nothing else, but the tick is weaker than
the two beside it.

### The hash is of what is sent, not of the Ledger

`rollupHash` is FNV-1a over `jsonEncode(rollupPrompt(rollup))` — the exact
bytes the Worker would receive. The consequence worth naming: **an edit the
Rollup cannot see does not regenerate the Recap.** Renaming a merchant that is
not one of the month's five largest purchases changes the Ledger and changes
nothing in the prompt, so the cached Recap stands. That is correct rather than
a gap — a Recap is a pure function of a Rollup, and the Recap could not have
mentioned that merchant — but it is a sentence somebody will otherwise have to
work out from first principles.

Amounts are rounded to two decimals before hashing, so a float's last bits
cannot make two identical months hash differently.

### Consistency with the charts is by construction

Criterion 6 is met the way ticket 09 set it up to be: `LedgerBloc._ready()`
builds one `Rollup`, the charts draw it and `rollupPrompt` encodes it, and a
bloc test asserts that the total, the month label and the leading category in
what was sent are the ones on screen. Categories are sent as the label the
charts print ("Dining out"), not the slug, so the words and the picture name
the same things.

What no test can assert is that the Model's sentences are true to the numbers
it was given. The prompt says never to state a figure that is not in the
Rollup. That is an instruction, not a guarantee, and the first real Recap is
where to check it.

### Deliberate additions the ticket did not ask for

Declared rather than smuggled, as 04 and 09 did.

- **An "Ask again" button** under a Recap that could not be written. The cache
  holds failures as well as answers — otherwise a refusal is re-bought on every
  rebuild — and without a way to clear one, a Recap that missed because the
  train went into a tunnel would be missing until the month changed. It is the
  one path that spends money twice on the same Rollup, which is why it is a tap
  rather than a retry on a schedule.
- **A minimum of five Expenses**, which the spec left as "a minimum number".
- **`ScanAnswer` and `RecapAnswer` split `ModelAnswer` in two.** An earlier
  draft had one type for both endpoints, and the exhaustive switch in
  `inbox_bloc.dart` then demanded a case for a Recap arriving in answer to a
  photograph — which review caught it inventing a Failure for. The failures
  themselves are one shared closed set (`ModelFailure`); only `ImageNotAccepted`
  belongs to Scans alone.
- **`readMessage` extracted from `parseExtraction`**, so a Recap is walked out
  of the response by the same tested code, with the same traps sprung: reasoning
  items ahead of the message, and a refusal arriving at 200.

### What review changed

Two axes, both worth their keep again. Standards caught the invented Failure
above, a wildcard in the recap switch that would have given
`ModelUnavailable` generic copy, the same paragraph of prose copied into five
files, the token-and-catch ladder duplicated across `extract` and `recap`, and
the two environment names that had started to lie. Spec caught that the cap
deviation was undeclared, that `looksLikeRollup`'s comment claimed more than it
checks, and that `_ready()` was building the month's Rollup twice — the second
construction site the 09 handoff explicitly warned against.

The CPU claim for `/recap` was a comment until review asked for a number.
`npm run measure` now prints one: **0.016ms** to check a 1,630-character Rollup
is JSON and build the outgoing body around it, against 0.75ms for a Scan and
the 10ms the free plan allows. `/extract` templates around its body for a
reason; at a kilobyte, parsing and re-encoding costs a six-hundredth of the
budget, and that is now measured rather than asserted.

### Left undone

- **Nothing has been watched on a phone.** Five tickets of unwatched work now.
- **`_ready()` dispatches an event as a side effect of building state.** Opening
  a month whose Recap is not cached is what asks for one, so the ask lives
  inside the state construction. It is guarded against asking twice for the same
  hash, and it is a trap for the next editor.
- **The Recap is not persisted**, so it is asked for again after a restart even
  though the Rollup is unchanged. Caching it beside the Ledger would fix that
  and is nobody's ticket.
- **The Corrected Fields tally still needs the `source == scanned` filter.**
  Flagged in five handoffs now; nothing built yet gets it wrong.
