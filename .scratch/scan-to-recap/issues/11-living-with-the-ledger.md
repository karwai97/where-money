# 11 — Living with the Ledger

**What to build:** The Ledger becomes something a user can live in rather than only
add to. Open an Expense and see what was actually bought, with the receipt photo
that produced it. Fix something noticed a week later. Delete a duplicate. Tell at a
glance which Expenses the app read and which were typed by hand.

The receipt image is the reason this ticket matters. "What was that 40 at the
supermarket" has an answer only if the Line Items and the photo are both still
there.

**Blocked by:** 03, 04

**Status:** done

- [x] The Ledger lists Expenses newest first
- [x] Opening an Expense shows its Line Items and its receipt image where one exists
- [x] A committed Expense can be edited, and the Check re-runs while editing
- [x] An Expense can be deleted, with confirmation
- [x] Scanned and manually entered Expenses are visually distinguishable
- [x] An Expense in a foreign currency displays the currency actually paid in
- [x] An Expense whose image is missing — restored on a new device — renders without breaking
- [x] Editing an Expense adds to its recorded corrected fields rather than replacing them

## Comments

All eight ticked, all eight by test, **none of them watched on a phone**. There
is still no Android device or emulator on this machine — `flutter devices`
offers Windows and Edge — so this is now the sixth ticket of unwatched work.
Criterion 7 in particular describes a phone the Ledger was restored onto, and
what was proved is that a store answering `null` renders the sentence instead
of the photo. That is the mechanism; the situation is untested.

### What the Expense gained

`Expense` grew five fields: `subtotal`, `tax`, `tip`, `paymentMethod`, and
`receiptPath`.

The first four are there because **the Check has to be able to run twice and
agree with itself**. An Expense used to drop the arithmetic it was committed
from, so reopening a clean scanned receipt compared its line items against a
total that included tax and raised a Finding on something the user had already
signed off. `packages/core/test/expense_test.dart` pins that round trip.
`paymentMethod` came along because the edit form offers the field, and offering
a field the save throws away is worse than not having it.

`receiptPath` is the spec's Persistence line — *"with the path recorded on the
Expense"* — which three handoffs had parked. It is a **name within the device's
Scan directory**, not an absolute path: the documents directory moves between
app versions and the file does not. `receiptPathFor` in `ledger_store.dart` is
the one place that naming is said, and `receiptAt` refuses anything that is not
a plain name in that directory, so a path out of a document is not a path the
app follows.

**Expenses already in a Ledger have no `receiptPath` and still find their
photo.** A scanned Expense carries its Scan's id, and the image is named after
the Scan, so `expense_document.dart` derives the path on read rather than
leaving every receipt committed before today unreachable. A manual Expense gets
no path invented for it.

### The date heuristic, and why it changed

Review's staleness Findings — "Date is unusually old", "Year looks misread" —
are behavioural claims about a receipt that has just been entered. Correcting a
merchant name on a three-month-old Expense opened with a Finding the user could
only settle by falsifying the date, **and falsifying it would have gone into
the Corrected Fields tally**, which is the project's one accuracy instrument.
`Check.of` now takes `alreadyReviewed`, and the edit lane passes it. Everything
else still runs: a date typed in during an edit that has not happened yet is
still caught, and so is arithmetic that stopped adding up. `check_test.dart`
holds all four cases.

`Expense.asExtraction()` was already dropping the Model's request for a human
to look for the same reason. This is the other half of that argument.

### Elsewhere

- **`LedgerStore` gained `remove` and `receiptAt`.** The store is still the only
  seam this ticket needed, as the 10 handoff predicted.
- **Ticket 10's criterion 4 is finished.** `the_recap_test.dart` now asserts
  that deleting an Expense makes the next open ask for a Recap again, through
  the bloc rather than at the hash level.
- **The Ledger list shows the Category label** the charts show, not the slug.
  One line, pre-existing, flagged in the last handoff.
- **`ReceiptOnScreen` was lifted out of the Review screen** so the Ledger and
  Review show the receipt through the same widget, and `HowItGotHere` says once
  how a Scan and a hand-typed Expense look.
- **The delete guard test changed shape.** It used to assert that
  `device_scan_store.dart` was the only file in `lib/` calling `.delete(`; the
  Ledger now deletes documents. It narrows to files that also hold `dart:io`,
  since a Scan is files and only something that can name a file can lose one.
  An earlier draft grepped for the literal call site and review was right to
  turn it down.
- **Firestore rules needed no change** — `allow write` already covers delete —
  but `rules.test.js` now proves a user can delete their own Expense and cannot
  delete a stranger's.

### What review changed

Both axes earned their keep again. Standards caught the source-text grep in the
delete guard, the newest-first widget test reading the widget tree instead of
what is on screen, two ad-hoc flags on the receipt widget, the store threaded
through four widget constructors, the source icon and its tooltip written out
twice, a five-site lane cascade in the Review bloc, and a duplicated doc
comment. Spec caught the whole receipt-path migration above, the date heuristic
above, an unhandled read failure that would have left a spinner forever, and
the payment method on the detail screen as scope creep — that line is gone,
though the field is still stored.

### Left undone

- **A refused delete says nothing.** The screen pops as soon as the user
  confirms, so a store that turns the write away leaves the Expense back in the
  list with no explanation. The row being there is true, and it is all the user
  gets. Review's refused-commit lane has words for this; deleting does not.
- **A deleted Expense leaves its receipt on disk.** Nothing points at the photo
  any more and nothing ever cleans it up. Committed Scans have the same
  problem, from ticket 06.
- **The Corrected Fields tally still needs the `source == scanned` filter.**
  Flagged in six handoffs now. This ticket is the first thing that can actually
  produce a wrong number — an edited manual Expense records corrections against
  an Extraction that never existed — and it still does. Nothing reads the tally
  yet, so nothing is wrong on screen.
- **A field typed over and typed back still counts as corrected.** Existing
  Review behaviour, now reachable from an edit as well. Arguably right: the user
  did have to look at it.
- **`needsReview` is recomputed on save and shown nowhere.** Editing an Expense
  can flip it, and no screen would say so.

### Watched on a device, 2026-08-25

A device appeared the day this ticket was committed. Everything below was
exercised on the OPPO CPH2499 on Android 16, against live Firebase and the
deployed Worker.

- **Opening an Expense works**, with the headline, the date and Category, the
  source line, and the no-Line-Items case reading as intended.
- **Editing works, and the Check runs while it does.** Typing a subtotal of
  20.00 against a total of 26.00 raised "Total does not add up — off by 6.00";
  typing 6.00 into Tax cleared it. The button says **Save**, not "Add to
  Ledger", and saving wrote over the same Expense.
- **The Category label reaches the list.** "Dining out", not "dining" — the
  loose end three handoffs had carried.
- **The typed-by-hand mark is on the row** and on the Expense itself.
- **The edit survived the round trip**: the source stayed manual and the screen
  re-read from the Ledger when Review popped.

A real receipt followed, and settled most of the rest.

- **Opening a scanned Expense shows the receipt**, resolved through the
  `receiptPath` this ticket added, on a real device store rather than a fake.
  Tapping it opens full screen and the thermal print is legible.
- **The scanned mark and the hand-typed mark are visibly different** — a receipt
  against a pencil — seen on real rows.
- **Deleting works, with the confirmation naming the Expense and its amount.**
  The Ledger fell back to "Nothing in August 2026" rather than "Nothing here
  yet", because the Ledger was not empty, only that month.

Two things are still only a test's word: **an Expense with Line Items** (a card
terminal slip has none) and **a foreign-currency Expense**. And the
missing-image line has still only been proved against a store answering null,
not against a phone the Ledger was restored to.

**One copy bug came out of it.** The delete confirmation promised "The receipt
photo stays on this phone" for an Expense typed by hand, which never had one.
It is now conditional, with a test either way.
