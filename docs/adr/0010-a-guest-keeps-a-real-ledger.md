---
status: accepted
---

# A guest keeps a real Ledger

The sign-in screen has offered two ways in for some time and only ever
delivered one. "Continue as guest" was drawn, wired and localised, and the
gateway behind it refused on purpose: every seam in the app is keyed by uid —
the Ledger, the Receipts directory, the Worker's token, the day's Scan
allowance — and what a guest's uid was supposed to be had not been decided.

**A guest is an anonymous Firebase account.** The alternatives were a
device-local identifier with no account behind it, and a read-only tour of the
app with sample data and no Ledger. The device-local identifier means either
inventing a second authorisation story for the Worker and for Firestore, or
keeping a guest off both — and a guest who cannot Scan has not seen this app,
because reading a receipt is the whole of what it does. The read-only tour has
the same problem with the added cost of building a second, fake version of
every screen. An anonymous account is a real uid, so nothing about the Ledger,
the Receipts, the cap or the rules changes at all.

**The Ledger a guest makes is theirs to keep.** Firebase links a Google
credential onto an existing anonymous account without changing its uid, so a
guest who later wants an account keeps the same uid and therefore the same
Ledger, the same directory and the same allowance. Nothing is copied and
nothing is migrated, which is the property that made this option worth having
over the others: a migration between two uids is a partial-failure state and
this is not.

**Because the identity cannot be recovered, leaving destroys it.** Nobody signs
into an anonymous uid twice. A guest who signs out and leaves their documents
behind has a Ledger that exists, is billed for, and can never be read again,
and a Receipts directory on the phone that nothing points at. So the exit is
destructive and says so before it happens: the Expenses go, the Scans and
Receipts go, what the phone remembers about the account goes, and the account
goes. The order is fixed — the account last, because the token that authorises
every other step dies with it — and only the Expenses are all-or-nothing: a
refusal there leaves the user signed in, which is the only state they can try
again from.

## Consequences

The anonymous sign-in provider must be enabled on the Firebase project.
Without it `signInAnonymously` fails with `operation-not-allowed` and the
guest button is exactly as broken as it was before this. It is enabled on the
current project; anyone standing up another one needs to know.

The Home Currency is cleared when a guest's Ledger is erased. It is stored
device-wide rather than per uid (ADR-0009 put it on the phone, and the
implementation took that literally), so without this the currency a guest's
Ledger taught the phone would be silently inherited by whoever signs in next.
Clearing it by hand here is a workaround, not the fix; the fix is filed at
`.scratch/the-home-currency-belongs-to-a-ledger`, and when it lands this
special case comes out.

An anonymous account is free and infinitely re-creatable, and each one gets a
full day of Worker calls against the project's model key. The daily cap counts
per uid and still counts correctly — it just no longer limits anything, because
identities are now free. Nothing has gone wrong yet: this is a personal app
with one user. It stops being theoretical the moment it is installed by anyone
who did not build it, and it is filed at `.scratch/guests-and-the-daily-cap`.

`LedgerStore` and `ScanStore` each grew a way to erase everything they hold.
Two existing rules made this the only honest shape: ADR-0002 keeps Firestore
below the repository, and a Scan is only ever deleted by the one class that
owns the directory it lives in. Both are enforced mechanically by the suite,
and an eraser that reached past them would have broken both. What sits above
those two calls owns the order and nothing else.

The record that says an erasure is owed survives the app being killed and not
a refusal. A refusal is caught by code that is still running and does know the
outcome, so it clears the record and tells the user; only a death leaves it
set. This matters more than it sounds: keeping a Ledger leaves the uid exactly
as it was and only stops it being a guest's, so a record matched on the uid
alone would, on some later launch, delete the very Ledger the user signed in
to save. Resuming also requires the restored user to still be a guest.

Two Ledgers cannot be merged. A guest who signs in to a Google account that
already has one is told, before anything is deleted, that the account's Ledger
is the one being opened and this one is going. Merging would be a cross-uid
migration with partial-failure states and two Home Currencies to reconcile,
for a case that is rare on a single-user app.

Nothing nags a guest to sign in. The offer sits in Settings, where the sign-out
row already is, and nowhere else.
