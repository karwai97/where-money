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

- [ ] A recap endpoint on the Worker, under the same auth and cap as extraction
- [ ] The current, incomplete month gets a Recap
- [ ] Reopening a month whose Rollup is unchanged makes no request
- [ ] Editing, adding or deleting an Expense causes the next open to regenerate
- [ ] Below the minimum Expense count, no request is made and the screen explains why
- [ ] The Recap's claims are consistent with the charts from ticket 09
- [ ] Only the Rollup is sent — no Expense list, no merchant-level detail beyond what the Rollup carries
- [ ] A failed Recap leaves the charts usable
- [ ] A test asserts that an unchanged hash makes no gateway call and a changed one does
