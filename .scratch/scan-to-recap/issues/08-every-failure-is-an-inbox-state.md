# 08 — Every failure is an Inbox state

**What to build:** Nothing about a failed Scan is a surprise or a dead end. The
Inbox shows what went wrong in words the user can act on, retries what can be
retried, and never loses a photo.

There are no modal error dialogs in this flow. A failure is a state a Scan is in,
which means it is visible whenever the user next looks rather than only at the
moment it happened. Offline is not a special case under this design — the job
simply has not run yet.

The failure taxonomy is the one the prototype established, and each member needs
its own copy because each means something different to the user: the model
refused; reasoning consumed the whole output budget so there is no text at all;
the network is gone; the daily cap is reached; the token was rejected; the photo
is not a receipt.

**Blocked by:** 07

**Status:** ready-for-agent

- [x] Each failure mode has its own Inbox state and its own plain-language copy
- [x] A refusal is distinguished from an incomplete response, and both from a network failure
- [x] Hitting the cap says so and says when it resets — never "something went wrong"
- [x] A Scan that failed on the network retries by itself once there is signal
- [x] Any failed Scan can be retried by hand without waiting for the automatic retry
- [x] No failure mode loses the image or the Scan
- [x] Retrying a Scan that has already succeeded is not possible
- [x] A test covers each taxonomy member through the faked gateway

## Comments

Implemented. The Scan record widened to carry why it failed and when the
allowance resets, the four placeholder lines in `inbox_screen.dart` became
seven that each say something different, and a failed Scan can now be read
again — by hand at once, or by itself while the signal is gone. All eight
criteria are ticked; criterion 4 is the weak one and is qualified below.
**Nothing here has been watched on a phone**, which is now three tickets of
unwatched work stacked up.

### The taxonomy grew a member, because one of them was lying

`ModelOutOfReach` was the catch-all arm of `worker_model_gateway.dart`, so
`model_unavailable` (502), `signing_keys_unavailable` (503) and anything a
later Worker invents all arrived as "no signal". Under ticket 07 that was
invisible — every one of them landed on the same `failed` line. Ticket 08's
whole point is that the line says something, and "No connection when this was
read" is false when the phone plainly has one.

So `ModelUnavailable` is now its own answer and `ScanFailure.modelUnavailable`
its own failure. It also settles a retry question: a call that reached the
Worker has **already spent an attempt against the day's allowance**, whereas
one that reached nothing spent nothing. Only `outOfReach` goes round by itself.
That is the same distinction ticket 07 drew when it split `ImageNotAccepted`
out, one layer further in.

### What "retries by itself once there is signal" actually means

**Nothing in this app listens to connectivity.** A Scan that failed with no
signal is swept back into `extracting` on a timer: 15 seconds, doubling while
the signal stays gone, up to eight times that — so roughly two minutes at the
worst. A phone that regains signal is read again within that, not the instant
the bars come back.

A connectivity listener would be a plugin and a third thing to fake, against
the spec's two-seams rule, and there is no device here to watch it on. The
copy was written to be true of what was built rather than of what the criterion
says: the line reads "It will keep trying on its own", not "as soon as there is
a connection", which is what the first draft promised and could not keep.

Two details make the sweep cheap. It reads **one** Scan per sweep, so a wallet
emptied into a dead network does not spend an attempt per receipt per sweep;
and any answer at all resets the wait *and cancels the pending sweep*, so the
backlog behind a Scan that just got through does not sit out a long wait that
has just been proved unnecessary.

### The cap is not a failure, and neither is a photo of a cat

`ScanState.capped` and `ScanState.notReceipt` stay their own states and carry no
`ScanFailure`. Both are asserted to carry none — the cap being reached is the
app working, and saying "could not be read" about it would be the exact
"something went wrong" the ticket forbids. The cap line names the moment it
resets, in `on_screen.dart`'s house format so the Inbox and the Ledger cannot
drift into two styles. Review raised that a bare timestamp is not warm copy;
the shared formatter won, because a second date style is a worse bug than a
cold one.

### Reading again by hand

Offered for `failed` and for `capped`, which is both retry arrows on the
lifecycle diagram. Review flagged the capped one as more than the criterion
asked for: a user can tap it while the cap is still spent. That costs a round
trip and nothing else — the Worker answers `cap_reached` from KV without
calling the Model — and it comes back with a fresh `resets_at`, so the tap is
harmless and mildly useful. Left in.

`canBeReadAgain` is a property of the Scan, so the button and the bloc cannot
disagree about it. **A Scan the Model has already read is never read again**,
which is asserted by trying: a second, different Extraction is armed, the event
is sent, and the first Extraction is still there afterwards. It fails when the
guard is removed.

### What is proved, and by what

- **Proved by test, through the real code.** Every taxonomy member landing in
  its own state with its own failure and its photo still on disk; a refusal
  being distinct from silence, and the Model being down from having no signal;
  the cap carrying its reset moment across a relaunch; the on-screen line for
  each of the seven failures plus the cap; a network failure going round again
  by itself; a Scan read again by hand from the Inbox; a Scan already read
  refusing to go again; a Scan abandoned while failing staying gone.
- **Confirmed to fail when deliberately broken**: the automatic sweep, the
  already-read guard, and `triesAgainByItself`. The sweep test fails by
  timing out rather than by asserting, which is the same weakness ticket 07
  found in one of its own — it fails, but it takes 30 seconds to say so.
- **Not proved at all.** Anything about the deployed Worker. The new
  `ModelUnavailable` mapping is covered against `MockClient` only, like the
  rest of `worker_model_gateway_test.dart`. **Google Sign-In has still never
  produced a token the live Worker accepted**, which the handoff warned would
  matter most here: `tokenRefused` is deliberately not swept, so a bad token
  cannot loop, but nobody has watched a real one succeed.
- **Not proved, and not provable here.** That the sweep behaves on a phone
  that loses and regains signal. The backoff and the sweep-cancel are argued
  for above, not measured.

### Left for the tickets that own them

- **A failed call still spends its allowance.** Unchanged from ticket 05, and
  now it has a retry sitting on top of it. The exposure is smaller than the
  handoff feared, because the failure that is swept automatically is the one
  that never reaches the Worker; a `model_unavailable` costs an attempt and is
  deliberately not swept. The refund on a failed call is still the real fix and
  is still a Worker change.
- **Nothing widened the Expense.** The image path on the Expense is still
  ticket 11's, as ticket 07 left it.
- **Knobs is still not a value object.** Ticket 13.
