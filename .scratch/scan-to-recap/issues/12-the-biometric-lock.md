# 12 — The biometric lock

**What to build:** Someone holding the user's unlocked phone cannot read their
spending. The app asks for a fingerprint or the device PIN when it opens, and the
user can turn that off if they would rather have the convenience.

This is deliberately separate from signing in, because the two do different jobs
and conflating them is the mistake. Signing in identifies the user to the Worker so
their Scan allowance can be counted — it protects the OpenAI bill. The lock
protects the data on this device. Neither substitutes for the other.

Also here: the new-device story. Signing in on a new phone brings back every
Expense from Firestore and no receipt images, because images are device-local by
design. That is a fine trade but a confusing surprise, so the app says it once
rather than leaving the user to notice missing photos.

**Blocked by:** 03

**Status:** done

- [x] The app requires biometric or device-PIN authentication on open when enabled
- [x] A device with no biometrics enrolled falls back to the device PIN
- [x] A device with no secure lock at all is handled without locking the user out of their own data
- [x] The lock can be turned off in settings, and the choice persists
- [x] Backgrounding and returning re-locks after a short interval, not on every task switch
- [x] Signing out is available and clears the session
- [x] Signing in on a device with no local images explains once that Expenses came back and photos did not

## Comments

Implemented, and **every criterion was watched on the OPPO CPH2499** — the
phone had no screen lock, so a temporary PIN was set with
`adb shell locksettings set-pin 1234` and cleared afterwards with
`locksettings clear --old 1234`. The phone is back as it was found; the user
agreed to this before it happened.

The spine is `DeviceLock` -> `LockBloc` -> `LockGate`, with `LocalAuthLock` the
only file that knows `local_auth` exists. Two new seams, both faked in tests:
`DeviceLock` and `DevicePreferences`. That makes four things this project fakes
rather than the two the spec's Testing Decisions names, and the count in that
section is now stale rather than wrong.

**The Lock is not signing in, and `CONTEXT.md` now says so.** A new **Lock**
entry under a new "The phone" heading. It is the one word this ticket needed
and the file had no home for it, so the heading is new too.

### Where the Lock sits, and why it is not beside the Ledger

`LockGate` lives in `MaterialApp.builder`, above the Navigator. Put in `home:`
instead it would sit *behind* any route the user had pushed, so a phone locked
while an Expense was open would cover the Ledger and leave the Expense
readable. Above the Navigator it covers everything.

The Ledger stays **mounted** under the lock — `AbsorbPointer` and
`ExcludeSemantics`, not an unmount — so unlocking puts the user back on the
screen they were on rather than at the top of the Ledger. That costs one thing
worth knowing: `find.text('...')` still finds covered widgets in tests, so the
widget tests assert with `.hitTestable()`.

The gate only exists while somebody is signed in. A fresh install asks for
Google before it asks for a fingerprint, which is the only order that works —
there is nothing to protect before there is a session.

### The bug only the phone could find

**Android reports `hidden` twice: once on the way out, and again on the way
back in, immediately before `resumed`.** The first version took every
`hidden`/`paused` as "the user left" and overwrote the timestamp, so the
return-side `hidden` landed 65 ms before `CameBack` and **every return looked
instant**. Forty seconds on the launcher never re-locked. `_leftAt ??=` is the
fix: the first going-away wins.

The unit tests all passed throughout, because they fed a tidy
`WentAway`/`CameBack` pair that no real device ever produces. The logcat that
found it:

```
23:51:42.072  paused
23:52:21.565  hidden      <- 39 seconds later, and treated as the departure
23:52:21.630  resumed
23:52:21.637  cameBack left=23:52:21.565
```

There is now a test feeding the real sequence, and it fails when `??=` goes
back to `=`.

### Every failure falls towards the user reaching their Ledger

Criterion 3 is not one branch, it is a rule, and it is enforced in three
places:

- `availability()` answering `none` — no prompt at all.
- `unlock()` answering `unavailable` — the phone could not ask, so the app
  opens.
- Any seam **throwing** — `LocalAuthException`, a `MissingPluginException`, a
  preferences read that fails — is caught in both `LocalAuthLock` and
  `LockBloc`. Without the bloc's catch, a throw left the gate on a spinner with
  no way past it, which is the lockout the criterion forbids. Found in review.

Watched live: with the lock setting still on, the device PIN was removed
underneath it and the app opened the Ledger rather than stranding anyone.

### What was watched, in order

- No screen lock at all: opens straight to the Ledger, Settings explains why
  and the switch is off and unusable.
- PIN set: `BiometricPrompt` over `MainActivity` **before** the Ledger. No
  fingerprint is enrolled on this phone, so what it asks for is the PIN —
  criterion 2 is the ordinary case here, not the fallback.
- Ten seconds on the launcher: no prompt. Forty seconds: prompt.
- Lock turned off in Settings, force-stop, cold start: no prompt. Turned back
  on, force-stop, cold start: prompt.
- Sign out from Settings: back to "Continue with Google".
- **The photos notice fired for real.** `flutter install` uninstalls first, so
  the phone became a genuinely new device: the Ledger came back from Firestore,
  the Scan directory was gone, and the dialog said so once. Signing out and
  back in did not say it again.

### Left undone, and two things worth arguing with

- **`setRecentsScreenshotEnabled(false)` is in `MainActivity`**, so the recents
  thumbnail does not show the Ledger. Without it the Lock is cosmetic — the
  ticket's first sentence is about someone holding the phone, and recents is
  the easiest way to read it. It is **unconditional**, which is the arguable
  part: a user who turned the Lock off still gets their thumbnail hidden.
  Making it follow the setting needs a MethodChannel, which this ticket did not
  earn. `FLAG_SECURE` was deliberately not used — it would also take away the
  user's own screenshots of their own charts. **Not verified**; there is no way
  to see a recents thumbnail through `adb`.
- **The interval is wall-clock.** `DateTime.now()` on both sides, so moving the
  system clock backwards defeats it. Doing that needs an unlocked phone, which
  is already the game over, so it is recorded rather than fixed.
- **The photos notice is remembered only after "Got it" is tapped.** Kill the
  app while the dialog is up and it comes back next launch. That is the right
  way round.
- **Sign out moved off the Ledger app bar into Settings.** Criterion 4 needs a
  Settings screen and two sign-out buttons would be worse. `test/app_test.dart`
  now taps through Settings.
- **`LedgerStore` gained `hasReceiptAt`** — whether a receipt is on this device
  without reading its bytes. Checking for missing photos by pulling every image
  into memory would have been the wrong seam.
- The Corrected Fields tally still needs its `source == scanned` filter.
  Untouched again.
