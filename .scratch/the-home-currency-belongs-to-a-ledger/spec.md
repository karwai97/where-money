# The Home Currency belongs to a Ledger, not to a phone

**Status:** needs-triage

Filed by `.scratch/a-guest-keeps-a-real-ledger/spec.md`, which works around this
by clearing the Home Currency when it erases a guest's Ledger.

## Problem Statement

ADR-0009 says the Home Currency is learned from a Ledger's first Expense and
then lives on the phone. The second half is implemented literally: it is stored
under a single un-suffixed preference key, while the two preferences next to it
are keyed by uid.

So the Home Currency is the device's, not the Ledger's. Sign out, sign in as
someone else, and their Ledger inherits a currency learned from yours — no
first Expense, no learning, no sign that anything was decided. `DevicePreferences`
already documents that the Scan allowance is the account's, "so a second account
on this phone has its own"; the Home Currency quietly is not.

The guest work made this visible rather than causing it: it promises that
leaving deletes everything the Ledger taught the phone, which is only true
because it clears this key by hand. Every other sign-out still leaks.

## Why it was not fixed there

The fix is not the storage. `main.dart` reads the Home Currency *before*
`runApp`, and hands it down as a plain value so the first frame is drawn knowing
whether there are totals to show — the same treatment as the theme and the
language, and for the same stated reason. At that moment there is no uid: the
session has not been restored, and `SessionUnknown` is the app's first state.

Making the key uid-suffixed means the first frame can no longer know the Home
Currency, which is the property that read was built to have.

## What a solution has to answer

- **Where the Home Currency is read now**, given the uid arrives after the first
  frame. Options: read it when the session resolves and accept that the Ledger's
  first frame does not know about totals; keep a device-level copy purely as a
  first-paint hint and treat the uid-keyed value as the truth; move it out of
  preferences entirely and onto the Ledger in Firestore, where it arguably
  belongs, at the cost of not having it offline on a cold start.
- **What ADR-0009 should say afterwards.** It is currently true as written and
  would need amending, or superseding, depending on which of the above wins.
- **What happens to the value already on existing devices.** One user today, so
  a migration is probably "adopt the existing value for the first uid that
  signs in", but it should be a decision rather than an accident.
- **Whether `locksOnOpen` moves too.** It should not — it is the phone's
  preference about the phone, and it is only mentioned here so the next person
  does not sweep it up by symmetry.

## Out of Scope

Changing how the Home Currency is *learned*, or letting a Ledger have more than
one. ADR-0009 settles both and neither is in question.

## Further Notes

Once this lands, the guest erasure should stop clearing the un-suffixed key by
hand and clear the uid-keyed one with the rest — the workaround and its comment
come out together.
