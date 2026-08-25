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

- [x] A captured Scan extracts without the user waiting on it
- [x] The Extraction lands in the Inbox and the user is not interrupted to deal with it
- [x] Review shows the receipt image beside the fields, and the image can be zoomed enough to read faint print
- [x] Findings are pinned above the fields when the Check flagged anything
- [x] A clean Extraction still requires one deliberate tap before an Expense exists
- [x] The model's stated reason for its Category choice is visible
- [x] Corrections made during Review are recorded by field name on the committed Expense
- [x] A photo the model says is not a receipt is offered for discard, not for Review
- [x] Committing a reviewed Scan writes exactly one Expense and removes it from the Inbox
- [x] Killing the app mid-extraction loses nothing; the Scan is picked up again
- [x] Bloc tests, against the faked gateway and store, assert the state sequence rather than the widget tree

## Comments

Implemented. `ModelGateway` is built and both halves of it exist — the Worker
client, and the fake every test runs against. `InboxBloc` grew the background
job; `ReviewBloc` grew a second lane. All eleven criteria are ticked and every
one is covered by a test, but **nothing here has been watched on a phone**,
which is the same gap ticket 06 left and is now one ticket wider. Read "What is
proved, and by what" before trusting any tick.

### The shape it took

`ModelGateway` returns a `ModelAnswer` rather than throwing. Every member of the
failure taxonomy is one of those, because each one has to end up as a state a
Scan sits in where the user can see it — a thrown exception would have to be
turned back into one anyway, one layer further from the boundary.

The background job lives in `InboxBloc`, and **it emits nothing itself**. Every
step writes to the store, and the Inbox learns about it through the same stream
the user's screen does. That is what makes the state sequence assertable without
reaching into the bloc: `captured` → `extracting` → `extracted` is what the
Inbox actually showed, not what the job says it did.

Three details in it are load-bearing and none is obvious:

- **A Scan sitting at `extracting` that this bloc never claimed is re-read.**
  There is only one job, so an `extracting` Scan it does not know about was left
  there by an app that died mid-read. Nothing is waiting for it and nothing else
  will pick it up. The worst case is a receipt read twice, against losing one.
- **`DeviceScanStore.put` writes a record only beside an image.** Capture puts
  the image down first, so the only thing this turns away is a Scan the user
  abandoned while the Model was still reading it. Without it, the job's final
  `put` resurrects a Scan the user threw away, complete with a photo that is no
  longer on disk. The fake mirrors the guard, which is why the abandon-mid-read
  test means anything.
- **Extraction is serialised, one Scan at a time.** Nothing forces it. A wallet
  emptied in one sitting would otherwise open a dozen calls at once against an
  allowance that only counts up, and ticket 05 already established that a call
  spends its allowance whether or not it succeeds.

### The Expense a Scan becomes carries the Scan's id

Deliberate, and it does two jobs. Firestore writes by document id, so a Scan
that somehow reaches Review twice overwrites rather than duplicating — "exactly
one Expense" is then a property of the data rather than of the control flow. And
it is what will find the receipt image later, since the image is filed under the
Scan id on disk.

The spec's Persistence section wants the image path recorded *on* the Expense.
It is not, and this id coincidence is standing in for it. Adding the field
touches the Firestore document mapping and its round-trip tests, which ticket 04
already parked in ticket 11's neighbourhood. Ticket 11 is where an Expense is
opened and its receipt shown, so that is where it should land — but it is a real
gap in the spec's letter, not a thing that was overlooked.

### Answering ticket 04's question about `needsReview`

Ticket 04 left this for 07 to decide with a scan in front of it: the "Model asked
for review" Finding names no field, so nothing the user corrects could settle
it, and a model-flagged Extraction would be `needsReview` forever.

It now does not count. A Finding that names no field is not about anything the
user could correct, and the only one that can reach a committed Expense is the
Model asking for a human to look — which one just did, because Review is
unconditional and nothing gets committed without one. `_needsReview` therefore
reads `null => false` where it read `null => true`. Every Finding that names a
field still counts until that field is corrected, which is the rule ticket 04
built and it is unchanged.

### What ticket 05 left as a client problem, now solved

- **The media type is sniffed from the bytes, not assumed.** Ticket 06 hands a
  photograph already inside 1024px back byte for byte, so a PNG picked from the
  gallery arrives as a PNG. Ticket 05 added `?media=` for exactly this and the
  first draft here hardcoded `image/jpeg`, which would have told the Worker a lie
  it then puts in a data URL.
- **`bad_image` and `image_too_large` are their own answer.** They came back as
  `ModelOutOfReach`, whose whole meaning is "try again later". They will never
  succeed on a retry, and ticket 08's automatic retry would have looped on them.
  `ImageNotAccepted` is the difference.

### What is proved, and by what

- **Proved by test, through the real code.** The state sequence a Scan moves
  through; each failure-taxonomy member landing in its own state with the image
  still on disk; the cap being distinct from a failure; a not-a-receipt photo
  never reaching Review; a force-quit mid-read being picked up by a second bloc
  over the same store; a Scan abandoned mid-read staying abandoned; corrections
  reaching the committed Expense by field name; committing writing one Expense
  and emptying the Inbox.
- **Proved by test, but weaker than it reads.** Criterion 3's zoom. The test
  opens the full-screen receipt view and finds it; that pinching it magnifies is
  `InteractiveViewer`'s behaviour and is asserted only by `maxScale: 8` being
  set. Criterion 4 is stronger than it looks — the Findings are asserted to
  survive scrolling the fields, which is the regression ticket 04 caught in
  review.
- **Not proved at all.** Everything about the deployed Worker. The gateway's
  tests use `MockClient`, which is `package:http`'s own and not a third seam;
  they cover the translation from `worker/README.md`'s statuses into the failure
  taxonomy, and nothing else. **Google Sign-In has still never produced a token
  the live Worker accepted.** Ticket 05 used anonymous users and the handoff
  flagged 07 as the first time it matters. It still has not been watched.

### Deliberately left for the tickets that own them

- **Knobs is still not a value object.** The spec says model tier, image long
  edge, reasoning effort and the daily cap "are passed through the app as a
  plain value object". `WorkerModelGateway` carries them as three constructor
  parameters with compiled-in defaults. Ticket 13 is where they start coming
  from Remote Config and is where the type belongs; making it now would be
  guessing at its shape.
- **A failed Scan records nothing about why.** `resets_at`, the reason a token
  was refused, and refusal-versus-silence are all read off the wire and then
  dropped, because `ScanState` is the only thing a Scan carries. Ticket 08 owns
  "says when it resets" and "a refusal is distinguished from an incomplete
  response", and it will have to widen the Scan record to do it. The taxonomy in
  `model_gateway.dart` is complete, so the material is there.
- **The four failure lines in `inbox_screen.dart` are still ticket 06's
  placeholders**, and ticket 08 should replace them. `captured` is now a state
  that flashes past rather than one a user sees, which is why two of ticket 06's
  widget tests moved from "Waiting to be read" to "Being read".

### Naming, and one thing that was renamed after review

`CONTEXT.md` refuses "queue" and "drafts" for the Inbox, and the first draft had
both: a `_queue` of Scans to read and a `_drafts` map of half-finished Reviews.
Now `_reading` and `_unfinished`. `ReviewInProgress` also grew a `copyWith`,
because it was being rebuilt field by field in four places and each one was a
chance to drop the receipt on the floor.

### Testing

Thirteen bloc tests in `test/scan/extraction_job_test.dart`, eleven in
`test/review/reviewing_a_scan_test.dart`, eight widget tests in
`test/scan/scan_to_expense_test.dart` covering the whole path from the shutter
to the Ledger, and nine in `test/scan/worker_model_gateway_test.dart`. The claim
guard and the two state mappings were each confirmed to fail when deliberately
broken.

`flutter analyze` clean, `flutter test` 119 passing, `dart test` in
`packages/core` 74 passing, `cd worker && npm test` 64 passing,
`flutter build apk --debug` builds.
