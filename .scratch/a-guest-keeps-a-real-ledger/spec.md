# A guest keeps a real ledger

**Status:** built. Three decisions below were overturned during
implementation, each marked **Amended** with what replaced it and why.

The sign-in screen's "Continue as guest" button is drawn, wired and localised;
`GuestRequested` reaches `SessionBloc`, which calls
`SignInGateway.continueAsGuest()`, which throws `UnimplementedError` on purpose
because what a guest is was not settled. This spec settles it and finishes the
path, including the way back out of it.

Supersedes open decision 1 in `.scratch/sign-in-screen/spec.md`.

## Problem Statement

A new user who does not want to hand over a Google account has a button that
looks like a way in and is not one. Tapping "Continue as guest" spends a moment
in the spinner and comes back with a red sentence saying the feature is not
built.

Behind the button sits a harder problem the user would meet immediately if it
worked: every seam in the app is keyed by uid — the Ledger, the Receipts
directory, the Worker's token, the day's Scan allowance — so a guest must have
one. A uid nobody signs into is a uid nobody can recover, which means a guest's
Ledger is one uninstall away from gone and the user has been told nothing about
that. And a guest who later decides they do want an account has no way to take
their Ledger with them.

## Solution

A guest is an anonymous Firebase account. The uid is real, so the Ledger, the
Receipts on disk and the Worker's daily cap all work exactly as they do for
anyone else — a guest photographs receipts, Reviews Extractions, commits
Expenses and reads Recaps with nothing withheld.

Because the account is real, it can be kept. Settings grows a row, visible only
to a guest, that trades the guest session for a Google account by linking the
credential to the existing uid. The uid does not change, so the Ledger does not
move: no copying, no migration, nothing to go wrong halfway.

And because the account is unrecoverable, leaving destroys it. A guest who signs
out is told plainly that their Ledger and Receipts go with them, and if they
confirm, everything belonging to that uid is deleted — the Expenses in
Firestore, the Receipts directory on the phone, the uid-keyed preferences, the
learned Home Currency, and the anonymous account itself. The promise the dialog
makes is the promise the code keeps, including when the app is killed halfway
through.

## User Stories

1. As a new user who does not want to give an app my Google account, I want
   "Continue as guest" to sign me in, so that I can start using the app at all.
2. As a guest, I want to land on the Ledger exactly as a signed-in user does, so
   that nothing tells me I am on a lesser version of the app.
3. As a guest, I want to photograph a receipt and have it extracted, so that the
   thing the app is for works for me.
4. As a guest, I want to Review an Extraction and commit an Expense, so that my
   Ledger fills up like anyone else's.
5. As a guest, I want my Ledger to learn a Home Currency from my first Expense,
   so that Rollups and Recaps work.
6. As a guest, I want the same daily Scan cap as any other user, so that I am not
   quietly rationed.
7. As a guest, I want to close the app and come back to my Ledger still there,
   so that the session is worth putting anything into.
8. As a guest whose sign-in cannot be completed, I want to see what the phone
   said, so that I know whether to try again.
9. As a guest who taps the guest button while a Google sign-in is already in
   flight, I want the button closed to me, so that two sign-ins do not race.
10. As a guest, I want Settings to offer me a way to keep this Ledger by signing
    in, so that choosing the guest path was not a one-way door.
11. As a guest reading that row, I want it to say what happens if I do not sign
    in, so that I understand what I am being offered rather than just being
    nudged.
12. As a guest who signs in from that row, I want my existing Ledger to be there
    afterwards with nothing missing, so that the row's promise is true.
13. As a guest who signs in from that row, I want the row to disappear once I
    have an account, so that the app is not still asking.
14. As a guest who opens the account picker from that row and then closes it, I
    want nothing to be said, so that I am not told about a decision I made.
15. As a guest whose linking is refused — no network, or the phone says no — I
    want the reason shown next to the row I tapped, so that I can see what
    happened without hunting.
16. As a guest whose linking failed, I want to still be a guest with my Ledger
    intact, so that a failed upgrade costs me nothing.
17. As a guest signing in to a Google account that already has its own Ledger, I
    want to be told that before anything happens, so that I am not surprised by
    which Ledger I end up in.
18. As that guest, I want the warning to say that this Ledger and its Receipts
    will be deleted, so that I can decide with the consequence in front of me.
19. As that guest, once I confirm, I want to end up signed into the Google
    account and looking at its Ledger, so that the thing I asked for happened.
20. As that guest, I do not want to be asked to pick the same Google account a
    second time, so that the flow does not read as broken.
21. As that guest, if I decline the warning, I want to still be a guest with my
    Ledger intact, so that reading a warning is safe.
22. As a guest who taps sign out, I want to be asked to confirm, so that I do not
    destroy a Ledger with one tap.
23. As a guest reading that confirmation, I want it to say that my Ledger and
    Receipts will be deleted and cannot be recovered, so that the words "sign
    out" do not mislead me.
24. As a guest who declines that confirmation, I want to be exactly where I was,
    so that backing out is free.
25. As a guest who confirms, I want to see that something is happening while it
    happens, so that a slow delete does not look like a frozen screen.
26. As a guest who confirms, I want my Expenses actually gone from the server, so
    that "deleted" means deleted.
27. As a guest who confirms, I want my Receipt photographs actually gone from the
    phone, so that images ADR-0003 kept local do not outlive the Ledger.
28. As a guest who confirms, I want the Home Currency my Ledger taught the phone
    cleared, so that the next person to use this phone is not silently given
    mine.
29. As a guest who confirms, I want the anonymous account itself deleted, so that
    nothing of me is left behind.
30. As a guest whose deletion is refused partway — no network — I want to stay
    signed in and be told, so that I am not locked out of a Ledger that still
    exists.
31. As a guest whose deletion failed, I want to be able to try again, so that the
    failure is not permanent.
32. As a guest whose phone killed the app in the middle of a deletion, I want the
    deletion finished the next time the app opens, so that I am not left with
    half a Ledger I never asked to keep.
33. As that user, I want that to happen without being narrated to me, so that I
    am not shown an implementation detail on launch.
34. As a user with a Google account, I want signing out to stay one tap with no
    confirmation, so that a reversible action is not given the weight of an
    irreversible one.
35. As a user with a Google account, I want no "sign in to keep this" row in
    Settings, so that I am not offered something I already have.
36. As a Chinese-reading guest, I want every new sentence in Chinese, so that the
    moment I am warned about losing data is not the moment the app switches
    language.
37. As a user at 200% text size, I want the new row and the dialogs to grow
    rather than clip, so that the warnings stay readable.
38. As a screen reader user, I want the upgrade row's failure sentence announced
    when it appears, so that I am not left to hunt for what changed.
39. As a maintainer, I want the decision about what a guest is written down as an
    ADR, so that the next person does not re-argue it.
40. As a maintainer, I want the deferred questions this raises — abuse of the
    Scan cap by disposable guests, and the Home Currency not being uid-keyed —
    filed rather than left in a comment.

## Implementation Decisions

### What a guest is

An anonymous Firebase account. Recorded as ADR-0010, *a guest keeps a real
ledger*, which states the decision, its consequences (an unrecoverable identity,
therefore a destructive exit; the anonymous provider must be enabled on the
Firebase project), and cross-references ADR-0009 for the Home Currency and
ADR-0003 for the Receipts. ADR-0009 itself is not amended — it remains true.

### The identity seam

`SignInGateway` stays what its doc comment says it is: identity, and nothing
more.

- `continueAsGuest()` becomes an anonymous sign-in. Its existing contract holds:
  no picker, so nothing to abandon.
- A new `linkWithGoogle()` opens the account picker and links the credential to
  the current user. It throws `SignInAbandoned` on a dismissed picker, exactly
  as `signIn()` does. When the credential already belongs to another account it
  throws a distinct, named exception carrying the credential to sign in with —
  taken from the platform's error where that supplies an updated one, falling
  back to the credential that was passed in. Callers must not have to recognise
  a platform error code.
- `SignedInUser` gains `guest`, read from the platform's anonymous flag. It
  belongs here because whether this identity is an account or a session is
  identity — the same category as the uid, not a field of a different kind.
- `changes()` moves from the auth-state stream to the user-changes stream.
  Linking does not change the uid and therefore does not fire the auth-state
  stream at all, which would leave the app believing a linked user is still a
  guest. The extra emissions the wider stream produces are harmless:
  `SignedInUser` is an `Equatable` of four fields, so a token refresh emits an
  equal value and no state changes.

### Erasing a Ledger

A new collaborator owns deletion. It is named for the act, not the caller, and
knows nothing about guests — it erases whatever uid it is given.

Its order is fixed and is the whole of its logic:

1. Record that an erasure of this uid is under way, in device preferences.
2. Delete the uid's Expenses, batched.
3. Delete the uid's Scans and Receipts directory on the phone.
4. Clear the uid-keyed preferences and the device's learned Home Currency.
5. Clear the record from step 1.
6. Delete the account.

The account goes last because the token dies with it and every earlier step is
authenticated by it. Step 2 is all-or-nothing: if it is refused the whole
erasure aborts and the caller is told, because signing the user out over a
failed delete would break the promise the dialog made *and* remove the only
identity that could retry. Steps 3 and 4 are best-effort — they are local,
invisible, and cleaned up by the OS or overwritten by the next uid.

It is reached through a per-uid factory on the app's root widget, mirroring the
existing per-uid stores factory. It is not folded into the stores themselves:
`ReceiptStore` documents itself as read-only on purpose, and `LedgerStore.remove`
documents that deleting a row must not reach into the camera roll. A bulk erase
would contradict both, in three interfaces, to avoid one parameter.

### Trading a guest for an account

A cubit owns the whole flow, named for the act. Settings constructs it; it holds
three states — idle, working, and failed with the detail — and calls the gateway
and the eraser directly with ordinary sequential code.

It is deliberately **not** in `SessionBloc`. Two reasons, both hard:

- `SessionBloc`'s `SigningIn` state routes the app to the sign-in screen. Any
  in-flight state expressed there would unmount Settings and the signed-in scope
  mid-flow.
- The collision path has to pause for a confirmation dialog, and a bloc cannot
  await one. Expressing it as state would split one user-visible flow across a
  state, a listener, a dialog and a second event.

`SessionBloc` keeps its four states and its existing public events unchanged,
and the app's top-level state switch does not move. The cubit never tells the
bloc anything: identity changes reach it through the gateway's stream on their
own.

The flows the cubit runs:

- **Upgrade.** Link. On success, nothing further — the stream reports the user is
  no longer a guest and the row disappears. On abandonment, silently back to
  idle. On refusal, failed with the detail.
- **Collision.** Link throws the already-in-use exception. The cubit asks for
  confirmation. If declined, back to idle with the guest and their Ledger
  untouched. If confirmed, erase the guest's uid, then sign in with the
  credential the exception carried. Nothing is deleted before the confirmation,
  and the credential is never re-collected from the user.
- **Leaving.** Confirmation first, then erase.

### The Settings screen

- A row above the sign-out row, drawn only when the user is a guest: a label
  offering to sign in to keep this Ledger, and a supporting line saying the
  Ledger lives on this phone only. The supporting line is not optional — the
  label alone does not say what happens if you decline.
- While the cubit is working on an upgrade, the row shows a spinner in place and
  Settings stays where it is. A failure draws a sentence beneath the row in the
  error role, announced to screen readers.
- The sign-out row keeps its existing label and shape for everyone. What differs
  is what it does: an account holder gets today's behaviour — one tap, no
  confirmation, the screen popped before the event — and a guest gets the
  confirmation, with Settings staying put, because the erasure can fail and has
  to be reported.
- Both destructive paths — leaving, and the collision after its confirmation —
  run under a blocking modal progress indicator. The plain upgrade does not: it
  is small, and a modal over it is heavy. Entering the modal at the point a
  deletion is confirmed is a change of register the user should feel.
- A failure dismisses the modal and appears as the same inline error sentence
  the upgrade row uses. One convention for where this screen says something went
  wrong.

### Interrupted erasure

~~The record written in step 1 is read on launch, in the state the app already
shows while it does not yet know who the user is.~~

**Amended.** The record is read in the composition root before the first
frame, alongside the theme, the language and the Home Currency, and handed
down as a plain value — the idiom this app already uses for what the first
frame has to know. Reading it inside the widget tree meant an asynchronous gap
before anything was drawn, which broke three existing tests: the notice that
says a restored Ledger's photos stayed behind is driven by a listener that
fires on *changes*, so delaying the Ledger's mount past its first arrival lost
the notice silently. Only the local read moved early; the erasure still runs
in the app, for the reason below. The wrapper that finishes an erasure is in
the tree only when there is one to finish.

Any erasure the record names is finished before the app draws anything else. Nothing is said about it: the user
confirmed a deletion and is about to land on the sign-in screen, which is the
outcome they asked for. **Amended:** a refused erasure — resumed or user-initiated — clears the record
rather than leaving it. The record means "started, and nobody knows whether it
finished", which is true of an app that was killed and false of a refusal this
code caught and reported. Left set after a refusal it becomes a landmine:
keeping a Ledger leaves the uid exactly as it was and only stops it being a
guest's, so a record matched on the uid alone would, on some later launch,
delete the very Ledger the user signed in to save. The resume also now
requires the restored user to still be a guest. Both guards are pinned.

It is not done before the app starts: blocking startup on a network delete gives
a guest on a bad connection a black screen with no way past it.

### Strings

Nine new keys in both ARB files, following the existing register — sentences
that name the thing, verbs as button labels. Two are additions this spec did
not foresee: the modal spinner needs something to say to a screen reader, and
the collision dialog cannot confirm with "Sign out" when what it does is sign
the user in.

The copy below is also corrected. The draft said a guest's Ledger "lives on
this phone only" and that leaving deletes it "from this phone", and both are
false: a guest's Expenses are in Firestore under a real uid, and ADR-0003
scopes the stays-on-device claim to images alone. The app's own
`ledgerPhotosStayedBehindBody` already draws the line correctly. "Ledger" is
also capitalised throughout, as every other user-facing string in the file
does — it is a domain word.

| Key | English |
| --- | --- |
| `settingsKeepThisLedger` | Sign in to keep this Ledger |
| `settingsKeepThisLedgerHint` | This Ledger has no account behind it, so it goes when this phone does. Signing in keeps it. |
| `settingsSignOutAsGuestTitle` | Sign out of this Ledger? |
| `settingsSignOutAsGuestBody` | Your Ledger and its receipts will be deleted, and cannot be recovered. |
| `settingsSignOutKeep` | Keep it |
| `settingsSignOutConfirm` | Sign out |
| `settingsAccountInUseConfirm` | Sign in |
| `settingsErasingInFlight` | Deleting this Ledger |
| `settingsAccountInUseBody` | That account already has a Ledger. Signing in opens it, and this Ledger and its receipts will be deleted. |

Neither dialog names a count. A number means the dialog waits on a read that can
fail or hang, for a figure that changes nobody's mind — the sentence that stops
someone is the one saying the loss is permanent.

Chinese is written for all seven at the same time. A half-translated screen is
worse than an imperfect translation when the untranslated half is the warning.
The Chinese wants a native read before it ships, and the commit body should say
so.

## Testing Decisions

A good test here drives the app the way a user does and asserts what the screen
says. None of these tests should know that a cubit exists, that linking throws a
particular exception, or in what order the eraser works — only that a guest who
confirms sign-out ends up on the sign-in screen with no Ledger behind them.

### The seam

Almost everything goes through the seam that already exists: the app's root
widget, constructed with fakes, as `app_test.dart` does today. The whole feature
is reachable from there — guest button, Ledger, Settings, both rows, both
dialogs, and back out.

Widened in place, no new seams:

- **The fake sign-in gateway** gains a guest flag on the user it yields, a
  `linkWithGoogle()`, and a refusal knob for linking beside its existing ones,
  with the already-in-use collision expressible through it. Same file, same
  style as `refuse` / `refuseGuest` / `refuseSignOut`.
- **The in-memory device preferences** already exist, so the erasure record and
  the uid-keyed keys need nothing new. The interrupted-erasure case is a
  preference set before the app is pumped.
- **`session_bloc_test.dart`** grows a case for `GuestRequested` reaching the
  gateway and one for a refused guest sign-in becoming a failure. Nothing else
  moves down to this level.

~~One new seam, mirroring the per-uid stores factory: a per-uid eraser factory
on the root widget, faked in tests with one that records what it was asked to
erase and can be told to refuse.~~

**Amended: no new seam.** With the stores doing the deleting, the in-memory
store erases for real, so the app-seam tests assert that the Ledger and the
Scans are actually empty rather than that a collaborator was called. It grew
two refusal knobs beside its existing ones, and the preferences fake one more.

### What gets pinned

At the app seam: a guest reaches the Ledger; a guest commits an Expense; the
upgrade row is drawn for a guest and not for an account holder; a successful
upgrade removes the row; an abandoned picker says nothing; a refused link leaves
the guest intact and shows the detail; the collision warns before it deletes;
declining the warning changes nothing; confirming it lands on the other account;
guest sign-out asks first; declining changes nothing; confirming erases and
lands on the sign-in screen; a refused erasure keeps the user signed in and
shows the detail; an account holder's sign-out is still one tap.

At the eraser: its order, that a refused Expense delete aborts it, and that
local failures do not.

At launch: a preference naming an unfinished erasure is finished before anything
is drawn, and a failed resume leaves it set.

### Prior art

`app_test.dart` for the app-seam tests and its `open` helper; `as_drawn.dart`'s
`markSaying` for reaching cased button labels; the abandon dialog in
`inbox_screen.dart` and the delete dialog in `expense_screen.dart` for the
confirmation shape and its tests; `settings_screen_test.dart` for reaching rows
on Settings; `session_bloc_test.dart` for the bloc cases.

The repo's cross-cutting invariants are extended rather than exempted:
`nothing_clips_at_twice_the_text_size_test.dart` covers the new row and both
dialogs, and `signing_in_speaks_chinese_test.dart` and `no_english_left_test.dart`
cover the new strings.

## Out of Scope

- **Rate-limiting disposable guests.** An anonymous account is free and
  infinitely re-creatable, and each one gets a full day's Worker calls. Real,
  and filed separately: it wants a proper answer at the Worker — per-device,
  per-IP, App Check — not a guest-shaped patch here.
- **Making the Home Currency uid-keyed.** It is device-wide today, which is why
  this spec clears it on erasure. The correct fix touches the startup read that
  happens before the uid is known, and is filed separately.
- **Merging two Ledgers.** A guest linking to an account that already has a
  Ledger discards one of them. Merging is a cross-uid migration with
  partial-failure states and a Home Currency conflict, for a case that is rare
  on a single-user app.
- **Prompting a guest to sign in.** No banner, no threshold, no nag. A guest
  chose the way round the account deliberately. If retention says otherwise, a
  prompt is a small addition on top of the row.
- **Restoring a deleted Ledger.** There is no undo and no grace period. The
  dialog says so.
- **Google's G on the sign-in button.** Still open decision 2 in the sign-in
  screen's spec, still untouched.
- **The sign-in screen itself.** The guest button is built, styled, localised and
  correct. Nothing on that screen changes.

## Further Notes

The anonymous provider must be enabled on the Firebase project before any of
this works. It already is on the current project, and the ADR records it so the
next person setting one up knows.

Two follow-up specs are written alongside this one at `needs-triage`, and the
ADR points at both: the guest abuse surface, and the uid-keyed Home Currency.

`locksOnOpen` is left alone in every path. It is the phone's preference, not the
Ledger's.

Run `flutter gen-l10n` after touching either ARB file.

Delivered on a branch with a pull request: this touches authentication, deletes
user data, and adds an ADR.
