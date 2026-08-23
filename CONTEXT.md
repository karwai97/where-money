# where_money

A personal expense tracker for a single user. A photographed receipt becomes a
categorised ledger entry, and a month of entries becomes a short written account
of where the money went.

## Language

### Capture

**Scan**:
One attempt to turn a photographed receipt into data. A Scan exists the moment
the photo is taken and is durable from then on; producing an Extraction happens
afterwards and may be pending, failed, or done.
_Avoid_: Upload, capture, snap, OCR

**Extraction**:
What the vision model claims it read from a receipt. Guaranteed to be
well-shaped; not guaranteed to be true. Never enters the Ledger directly.
_Avoid_: Parse, result, response, prediction

**Check**:
The on-device arithmetic and plausibility pass over an Extraction. Produces
Findings; costs nothing and calls nothing.
_Avoid_: Validation, verification

**Finding**:
One thing a Check noticed, at severity warn or fail. A clean Extraction
produces none at all.
_Avoid_: Error, issue, warning, flag

**Inbox**:
The set of Scans not yet Reviewed — some still extracting, some failed, some
ready. The only place an Extraction is ever seen.
_Avoid_: Queue, pending, drafts, unprocessed

**Review**:
The user confirming or correcting an Extraction before it becomes an Expense.
Always happens, even for a clean Extraction.
_Avoid_: Edit, confirm, approve

**Corrected Field**:
A field the user changed during Review. The set of these across the Ledger is
the project's only real measure of extraction accuracy.
_Avoid_: Diff, override, fix

### Ledger

**Expense**:
A reviewed, committed record of money spent. The only thing charts and Recaps
are ever built from.
_Avoid_: Transaction, purchase, entry, spend

**Ledger**:
The complete set of a user's Expenses.
_Avoid_: History, records, book

**Line Item**:
One priced row within an Expense, carrying its own Category.
_Avoid_: Item, product, detail

**Category**:
A member of the closed spend taxonomy. Closed on purpose: it is sent to the
model as an enum, which is what makes the field unguessable rather than free
text.
_Avoid_: Tag, label, type

**Home Currency**:
The single currency Rollups and Recaps are computed in. An Expense in any other
currency is stored faithfully and excluded from aggregation, and the exclusion is
shown rather than hidden.
_Avoid_: Base currency, default currency

### Narrative

**Rollup**:
A month of the Ledger reduced to totals, deltas, and outliers. Deterministic,
computed on device, and small.
_Avoid_: Aggregate, stats, digest

**Recap**:
The written account of a month's spending, generated from a Rollup rather than
from the Ledger. "Where your money went" is user-facing copy for a Recap, never
an identifier.
_Avoid_: Narrative, summary, story, insight

## Vocabulary this project does not use

**"AI"** as a noun in code. The thing being called is a Model; what comes back is
an Extraction or a Recap.
