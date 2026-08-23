# 11 — Living with the Ledger

**What to build:** The Ledger becomes something a user can live in rather than only
add to. Open an Expense and see what was actually bought, with the receipt photo
that produced it. Fix something noticed a week later. Delete a duplicate. Tell at a
glance which Expenses the app read and which were typed by hand.

The receipt image is the reason this ticket matters. "What was that 40 at the
supermarket" has an answer only if the Line Items and the photo are both still
there.

**Blocked by:** 03, 04

**Status:** ready-for-agent

- [ ] The Ledger lists Expenses newest first
- [ ] Opening an Expense shows its Line Items and its receipt image where one exists
- [ ] A committed Expense can be edited, and the Check re-runs while editing
- [ ] An Expense can be deleted, with confirmation
- [ ] Scanned and manually entered Expenses are visually distinguishable
- [ ] An Expense in a foreign currency displays the currency actually paid in
- [ ] An Expense whose image is missing — restored on a new device — renders without breaking
- [ ] Editing an Expense adds to its recorded corrected fields rather than replacing them
