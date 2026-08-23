# 09 — Rollup and two charts

**What to build:** A user picks a month and sees where the money went: a breakdown
by Category, and how this month compares to last. If any Expenses were left out
because they were paid in another currency, the app says how many rather than
quietly producing a total that doesn't reconcile.

Two charts, not a dashboard. The breakdown answers "what did I spend on", the
month-over-month trend answers "is this getting worse", and the trend is nearly
free because the Rollup already computes those deltas for the Recap to use. The
trend is also what makes the Recap checkable later — read that dining went up 40%,
then look at the chart and see it.

The Rollup is computed on device in pure Dart and is never written to Firestore.
One truth, and it stays deterministic and testable.

**Blocked by:** 02, 03

**Status:** ready-for-agent

- [ ] The Ledger can be filtered to a month
- [ ] A category breakdown for the selected month
- [ ] A month-over-month trend covering enough months to show a direction
- [ ] Expenses outside the Home Currency are excluded from both charts, and the excluded count is on screen
- [ ] A month with no Expenses renders as empty rather than as an error or a zeroed chart
- [ ] Nothing derived from the Rollup is persisted
- [ ] Charts are legible in both light and dark themes
