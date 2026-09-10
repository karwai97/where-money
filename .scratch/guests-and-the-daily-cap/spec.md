# Guests and the daily cap

**Status:** needs-triage

Filed by `.scratch/a-guest-keeps-a-real-ledger/spec.md`, which deliberately gave
guests the same cap as anyone else and left this open.

## Problem Statement

The daily cap is per uid. The Worker verifies a Firebase ID token, takes
`caller.uid` from it, and counts that uid's Scans and Recaps against
`DAILY_MODEL_CEILING`. That works because, until now, getting a uid meant owning
a Google account.

A guest is an anonymous account. Anyone can make one, instantly, with no
address to verify and nothing to exhaust — and then make another. So the cap
still counts correctly and no longer limits anything: the ceiling is per
identity, and identities are now free. Every one of them spends against the
project's OpenAI key.

Nothing has gone wrong yet. This is a single-user personal app and the exposure
is theoretical today. It stops being theoretical the moment the app is
installed by anyone who did not build it.

## Why this was not solved in the guest spec

Because the guest-shaped fix is the wrong shape. `verifyIdToken` does not read
the `firebase` claim at all today, and teaching it to read `sign_in_provider`
so it can hand anonymous callers a smaller number would put an authentication
seam in the business of knowing what a guest is, to solve a problem guests only
happen to expose. The hole is that the Worker trusts identity as a proxy for
scarcity, and that is true of every free identity, not only anonymous ones.

## What a solution has to answer

- **What is actually scarce.** Not the uid. Candidates: the device, the network
  path, an attestation that the caller is a real install of this app.
- **Whether Firebase App Check is the answer.** It is the thing built for this,
  it works with anonymous auth, and it would let the Worker reject callers that
  are not this app before any counting happens. Cost: a second token on every
  request, a platform integration on Android and iOS, and something to do in
  tests and in debug builds.
- **Whether a lower anonymous ceiling is worth having anyway** as a cheap first
  cut, accepting that it is bypassed by making a second guest.
- **What the user is told** when they hit a limit they did not know applied to
  them. `capReached` already has words for a reached cap; a rejection that is
  about who is calling rather than how much they have used is a different
  sentence, and CONTEXT.md is clear that the cap is not a Failure.
- **Whether any of it belongs on the phone.** Probably not — anything the client
  enforces, a client can decline to enforce.

## Out of Scope

Removing the per-uid cap. It is right and it stays; this is about what sits in
front of it.

## Further Notes

Worth triaging against the actual plan for the app. If it stays a personal build
signed and installed by one person, this can sit indefinitely. If it goes near a
store listing, it blocks that.
