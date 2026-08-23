---
status: accepted
---

# Capture and extraction are separate steps

A Scan writes its image to disk and creates a pending record immediately; that
step touches no network and cannot fail. Extraction runs afterwards as a
background job, and the finished Extraction waits in an inbox for Review. The
obvious alternative — hold the user on a spinner for the 3–8s round trip — was
rejected because it makes latency and offline into error states that each need
handling.

Under this shape, offline is not a special case: the job simply has not run
yet. Network failures, the daily cap, and model refusals all become inbox
states rather than modal errors.

## Consequences

- Review always happens, even for an Extraction that passes every Check. The
  prototype's most instructive failure was a misread year that satisfied every
  arithmetic check, so a clean Check is not evidence of a correct read — it
  earns a pre-filled form and one tap, not a silent commit.
- Which fields the user changes during Review is recorded on the Expense. That
  tally is the project's only measure of extraction accuracy, and the input to
  any future decision to move off the nano tier.
