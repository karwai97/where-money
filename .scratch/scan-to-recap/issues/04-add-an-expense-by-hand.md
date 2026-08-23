# 04 — Add an Expense by hand

**What to build:** A user taps add, types in a purchase that had no receipt, and
it becomes an Expense. Every field is editable, Line Items can be added and
removed, and the Check runs as they type — fix a total that doesn't add up and
watch the warning clear.

This ticket builds the Review screen before there is anything to review. That is
deliberate: manual entry is a real requirement on its own, cash and online
purchases exist, and the screen is the one the scan pipeline will reach later.
Building it against an empty Extraction rather than a model response means it can
be finished and demoed with no Worker, no camera and no network.

The instrumentation is not optional decoration. Every edit is recorded by field
name and stored on the committed Expense. On a manual entry that tally is
meaningless, but the mechanism has to exist here because it is what ticket 07
measures with, and it is the only evidence that will ever answer whether the
cheap model is accurate enough.

**Blocked by:** 02, 03

**Status:** ready-for-agent

- [ ] Manual entry opens the editor with an empty draft and commits with source recorded as manual
- [ ] Every field is editable, including currency and payment method
- [ ] Line Items can be added, edited and removed
- [ ] Findings re-evaluate on each keystroke — a flagged total stops being flagged when corrected
- [ ] Findings are shown in plain language above the fields, not as raw rule names
- [ ] Category is chosen from the closed taxonomy, with no free-text option
- [ ] Committing writes exactly one Expense
- [ ] Each edited field is recorded by name on the committed Expense
- [ ] Leaving the editor and returning does not lose in-progress work
- [ ] A field the user has corrected no longer counts as needing review
