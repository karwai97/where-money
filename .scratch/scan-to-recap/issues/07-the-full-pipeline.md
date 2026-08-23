# 07 — The full pipeline

**What to build:** The tracer bullet completes. A user photographs a receipt, puts
the phone away, comes back, and finds the receipt read and waiting. They see the
photo beside the fields the model read, glance at anything flagged, tap once, and
it is an Expense in their Ledger.

This is glue between things that already work — capture from 06, the Worker from
05, parsing and the Check from 02, the editor from 04 — plus the background job
that joins them. A `captured` Scan is picked up, sent, parsed, Checked, and moved
to `extracted`, where it waits in the Inbox for the user rather than interrupting
them.

Review is unconditional, including when every Check passes. The prototype's most
instructive failure was a misread year: a valid ISO date in the past that
satisfied every arithmetic and range check, and was wrong. There is no way to
catch that from the receipt alone, so a clean Check earns a pre-filled form and
one tap — never a silent commit. Two lanes reach the same screen with different
framing, clean and flagged; a photo the model says is not a receipt is offered for
discard instead.

The Scan states, from the prototype's design. `captured` requires no network and
cannot fail:

```
captured ──▶ extracting ──▶ extracted ──▶ (Review) ──▶ committed
                 │                              │
                 ├──▶ failed ──(retry)──▶ extracting
                 ├──▶ capped ──(tomorrow)─▶ extracting
                 └──▶ notReceipt ──▶ discarded
```

**Blocked by:** 02, 04, 05, 06

**Status:** ready-for-agent

- [ ] A captured Scan extracts without the user waiting on it
- [ ] The Extraction lands in the Inbox and the user is not interrupted to deal with it
- [ ] Review shows the receipt image beside the fields, and the image can be zoomed enough to read faint print
- [ ] Findings are pinned above the fields when the Check flagged anything
- [ ] A clean Extraction still requires one deliberate tap before an Expense exists
- [ ] The model's stated reason for its Category choice is visible
- [ ] Corrections made during Review are recorded by field name on the committed Expense
- [ ] A photo the model says is not a receipt is offered for discard, not for Review
- [ ] Committing a reviewed Scan writes exactly one Expense and removes it from the Inbox
- [ ] Killing the app mid-extraction loses nothing; the Scan is picked up again
- [ ] Bloc tests, against the faked gateway and store, assert the state sequence rather than the widget tree
