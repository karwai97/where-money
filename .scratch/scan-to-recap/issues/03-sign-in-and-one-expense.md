# 03 — Sign in, and one Expense round-trips

**What to build:** A user signs in with Google and sees a Ledger. The Ledger has
exactly one Expense in it, put there by a debug button rather than by a receipt —
but it was written to Firestore, read back, and rendered, which proves the spine
the rest of the app hangs on.

This is the ticket that establishes the seam. The repository is the only place
Firestore's shape is known; nothing above it ever sees an untyped document.
Security rules restrict every path to its owning user, and a signed-out or
wrong-user read is refused by the rules rather than by app code.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Signing in with Google succeeds on a physical device, with SHA-1 registered
- [ ] The session survives killing and relaunching the app
- [x] A debug action writes an Expense, and it appears in the Ledger list
- [ ] The Expense survives a relaunch, and survives a reinstall
- [x] No type above the repository mentions a Firestore document, snapshot or map
- [x] Security rules deny reads and writes to another user's path, verified by test rather than by inspection
- [x] Signing out clears the Ledger from view

## Comments

Implemented. The spine is `SignInGateway` -> `SessionBloc` -> `LedgerScreen` ->
`LedgerBloc` -> `LedgerStore`, with `FirestoreLedgerStore` the only file that
knows what a document is.

Four criteria are ticked; **three are not, because they need a physical device
and I have none**. Signing in, the session surviving a relaunch, and the Expense
surviving a relaunch and a reinstall are all unverified. The debug APK builds and
the rules are deployed, so they should hold, but nobody has watched them.

Google Sign-In is `google_sign_in` v7 plus `firebase_auth`, chosen for the native
account picker user story 1 asks for. Two things about v7 worth writing down,
because most of what is written about the package is v6: `authenticate()`
replaces `signIn()` and throws rather than returning null on cancellation, and
`account.authentication` is a synchronous getter carrying only an `idToken` —
the access token moved to `authorizationClient` and Firebase does not need it.
No client id appears in Dart at all: the Gradle plugin turns the web OAuth entry
in `google-services.json` into `default_web_client_id`, which the platform side
reads.

**Rules are verified by running them, not by reading them.** `firestore.rules`
restricts `users/{uid}/**` to its owner, and ten tests in
`tools/firestore-rules/` run against the Firestore emulator under a `demo-`
project id: own read, own list, own write, another user's read, list, create and
overwrite, signed-out read and write, and paths the app does not use. That is a
Node project, deliberately outside the Dart workspace, and the README says how to
run it. The rules were also deployed to `where-money-72ee2`, since a Firestore
database with default rules refuses everything and the device criteria would fail
for the wrong reason.

The seam is `LedgerStore` with two methods, `ledger()` and `add()`. That is all
this ticket needs; Scans and image bytes join it when ticket 04 exists. The
boundary is enforced mechanically as well as by convention — a test greps `lib/`
for `cloud_firestore` and allows exactly two files, the repository and the
composition root. It proves no import rather than no type, which is weaker than
the criterion's wording, but you cannot name a Firestore type without importing
it, and it fails in CI rather than in review.

Five things were changed after review rather than shipped as first written.

**A document with no legible total or date now throws.** It read as 0.00 and
1970 respectively, which is exactly the confidently-wrong-total the whole spec is
against. Everything else still falls back.

**Signing out no longer depends on Google agreeing.** The handler returned an
un-awaited future; if `google_sign_in` threw — no network, no Play services — the
error escaped as a bloc error and the user stayed signed in with the Ledger on
screen. It now catches and ends the session anyway, with a test.

**The empty-Ledger copy no longer points at a button that release builds do not
have.** The debug FAB is `kDebugMode`-gated; the copy was not.

**A refused write is dismissable**, and neither it nor the sign-in failure prints
a raw exception as the whole message any more. Copy carries the sentence; the
underlying error sits below it, smaller.

**`LedgerScreen` took a `SignedInUser` it never read.** Removed. The uid reaches
it through the store, which is the spec's "auth collapses into store
construction" and did not need a second route.

Two deliberate departures from the spec's testing rules, both arguable.

There is a third fake, `FakeSignInGateway`, alongside the two the spec names.
"Signing out clears the Ledger from view" is not testable without one, and the
alternative — reaching for `firebase_auth`'s own test doubles — would be a bigger
fake, not a smaller one. It is fourteen lines.

And `test/app_test.dart` is widget tests, which the spec's "never on widget
trees" argues against. Three of this ticket's criteria are literally about what
is on screen — a Ledger appearing, a Ledger clearing, a debug button working —
so the assertions are on visible text and tooltips, never on structure. The one
assertion that was genuinely about the tree, on `CircularProgressIndicator`, was
deleted in review. Everything about state sequences lives in the bloc tests where
the spec puts it.

Left for later, so it is not a surprise: `LedgerStore` has no update or delete,
because nothing has asked for one; the Ledger has no month filter, which is
ticket 09's; and `expenseToDocument` writes the date as an ISO-8601 string rather
than a Timestamp, so month ranges stay string comparisons and the mapping stays
testable with no Firestore in the room.
