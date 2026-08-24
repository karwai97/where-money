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

- [x] Manual entry opens the editor with an empty draft and commits with source recorded as manual
- [x] Every field is editable, including currency and payment method
- [x] Line Items can be added, edited and removed
- [x] Findings re-evaluate on each keystroke — a flagged total stops being flagged when corrected
- [x] Findings are shown in plain language above the fields, not as raw rule names
- [x] Category is chosen from the closed taxonomy, with no free-text option
- [x] Committing writes exactly one Expense
- [x] Each edited field is recorded by name on the committed Expense
- [x] Leaving the editor and returning does not lose in-progress work
- [x] A field the user has corrected no longer counts as needing review

## Comments

Implemented. `ReviewBloc` -> `ReviewScreen`, sitting on the `LedgerStore` seam
ticket 03 left. All ten criteria are ticked and every one is covered by a test;
none of them needed a device, so unlike ticket 03 there is nothing left unticked
for want of hardware. What has **not** been watched on a phone is the round trip
— a manual Expense reaching Firestore and coming back with `source` intact. The
mapping and its test are ticket 03's and unchanged, so it should hold, but say
so rather than claim it.

### The core changes, which were not optional

Three things had to move in `packages/core`, and the third is a behaviour change
to code ticket 02 shipped.

`Expense.fromExtraction` hardcoded `ExpenseSource.scanned`. It now takes a
`source`, defaulting to scanned so the scan path reads the same.

`Extraction.blank()` is the empty Extraction manual entry starts from. It sets
`isReceipt: true`, which looks like a lie and is the lesser one: there is no
image here for that question to be about, and `false` makes the Check open with
"Not a receipt" across a form the user is about to fill in.

**`needsReview` is now per field.** It was `!isConsistent && correctedFields
.isEmpty` — any correction anywhere cleared the flag on everything. Correcting
the merchant would have marked a wrong total as reviewed, which is precisely the
confidently-wrong-total the spec exists to prevent. Findings now carry the
`ReviewField` they are about, and a Finding only stops counting when that field
is in `correctedFields`. One ticket-02 test asserted the old coarse rule and was
rewritten; the case it covered (flawed Extraction, `['purchasedAt']` corrected,
expected not needing review) is simply false under this ticket's last criterion.
The complement — correcting one field does not settle another — is now a test.

### What the Corrected Fields tally records, and what it does not

Every field the user changes is recorded, on manual entries too, because ticket
07 measures with this mechanism and it has to exist. The ticket already says the
manual tally is meaningless. It is not merely meaningless but actively
misleading if read raw: a hand-typed Expense records
six "corrections" against an Extraction that never existed. **Whatever computes
the accuracy tally in ticket 07 must filter to `source == scanned`.** The field
is on the Expense for exactly that.

Two things deliberately do not count as corrections:

- Retyping the value a field already holds. Focusing a field and typing nothing
  that changes it is not a look at the receipt.
- Adding an empty Line Item row. This one was a real defect caught in review: a
  bare row records `lineItems` as corrected, which settles the "line items do
  not match subtotal" Finding — a Finding the empty row has just made *worse*.
  Adding a row now records nothing until something is typed into it. Removing a
  row does count, unless it is the empty one just added.

### Things changed after review rather than shipped as first written

- The empty-row correction above.
- The half-typed number fallback read `"-"` as a total of 0 and `"1e"` as 1. It
  now only forgives a trailing decimal point, which is the case it was for.
- Findings sat inside the scroll view and scrolled away while the user corrected
  what they named. They are pinned above it now, which is what the spec's
  flagged lane asks for.
- Review's route popped on "the state is idle", which is also true on the first
  frame and would have stranded the user on a blank page if the seeding event
  ever failed to arrive. It pops on the transition into idle, and the idle
  branch carries an AppBar so back always works.
- The Line Item rows were rendered from a `setState`-maintained copy of the list
  alongside the bloc's, with a defensive index check papering over the gap. Rows
  render from the Extraction now; the local list only stores their controllers.
- Naming against `CONTEXT.md`. The first draft was full of the words this
  project refuses: `FieldEdited`, `ReviewEditing`, `_Editor`, `ManualEntry
  Started`, and test names about things being "flagged" and "fixed". Now
  `FieldCorrected`, `ReviewInProgress`, `_Form`, `ManualExpenseStarted`, and
  tests that talk about Findings and corrections.

### Deliberate additions the ticket did not ask for

Both are declared rather than smuggled.

**A date picker** beside the date field. The criterion is that every field is
editable; a bare ISO text field technically satisfies it and is a bad way to
enter a date on a phone. It is not user story 35's one-tap year fix, which is
still ticket 07's.

**A visible commit refusal.** "Committing writes exactly one Expense" cannot be
trusted if a refused write is silent, and ticket 03 already established that a
refusal is shown rather than swallowed. The typing stays on screen.

The Ledger's empty-state copy changed too, and that one was forced: it told
release users to photograph a receipt, and there is now an add button and still
no camera.

### Left undone, on purpose

- **There is no way to discard work in progress.** Leaving Review keeps the
  typing, which is the criterion, and committing clears it — but a user who
  typed junk has no escape but to commit it. Discarding belongs with the Inbox's
  abandon action in ticket 06 or 08.
- **The "Model asked for review" Finding has no field**, so nothing the user
  corrects can settle it. Harmless here — a blank Extraction never raises it —
  but on the scan path it means a model-flagged Extraction is permanently
  `needsReview`. That is a real question for ticket 07 to answer with a scan in
  front of it, not to guess at now.
- **`categoryReason` is not shown.** User story 33 wants it, and there is no
  reason to show on something the user typed themselves. Ticket 07.
- **`Expense.correctedFields` stays `List<String>`** rather than
  `List<ReviewField>`, so `_needsReview` round-trips through `field.name`.
  Typing it would be better and would touch the Firestore document mapping and
  its round-trip tests, which is ticket 11's neighbourhood rather than this
  one's.
- **`ReviewState` is not Equatable**, unlike `LedgerState`. That is deliberate:
  an Extraction is compared by identity, so a keystroke that leaves every field
  looking the same still reaches the screen. The cost is that the bloc tests
  pump the event queue and cast rather than using `blocTest`'s `expect:`.

### Testing

Twenty bloc tests in `test/review/review_bloc_test.dart` and eight widget tests
in `test/review/review_screen_test.dart`, plus the core additions. The widget
tests follow ticket 03's precedent — assertions on text the user can read,
widget types only as a way to reach a field and type into it — and the one
assertion that was genuinely about the tree ("there is no Category text field")
was deleted in review, as ticket 03's was. The closed-taxonomy criterion is
covered by opening the Category list and checking what it offers.

`flutter analyze` clean, `flutter test` 58 passing, `dart test` in
`packages/core` 64 passing, `flutter build apk --debug` builds.
