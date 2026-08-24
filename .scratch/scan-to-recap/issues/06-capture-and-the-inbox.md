# 06 — Capture and the Inbox

**What to build:** A user photographs a receipt and the app is immediately done
with them. The photo is saved, a Scan appears in the Inbox, and they can
photograph the next one without waiting. Nothing is extracted yet — the Inbox just
shows Scans sitting at `captured`.

The point of this ticket is that capture cannot fail. It touches no network, so it
works in airplane mode and in a basement, and it is durable the moment the shutter
fires. Clearing a wallet of receipts should be one sitting, not ten round trips.

The image is resized on device to roughly 1024px on the long edge before it is
stored. The prototype measured that a portrait receipt saturates the model's patch
budget at about 1440px, so asking for the phone's full resolution bills identically
while costing real upload bandwidth.

**Blocked by:** 03

**Status:** ready-for-agent

- [x] A photo can be taken with the camera or chosen from the gallery
- [x] The Scan and its image exist on disk before the capture screen is dismissed
- [x] Capture works with the network off, with no error and no difference in behaviour
- [x] Several receipts can be captured back to back with no waiting between them
- [x] The stored image is resized to roughly 1024px on the long edge
- [x] The Inbox lists every un-Reviewed Scan with its state
- [x] Scans survive force-quitting the app
- [x] The Inbox count is visible from the main screen
- [x] A Scan can be abandoned, which removes its image from disk
- [x] Nothing but the user deletes a Scan

## Comments

Implemented. `InboxBloc` -> `InboxScreen`, on a `LedgerStore` seam that grew a
Scan half. All ten criteria are ticked, but **none of them has been watched on a
phone** — there is no Android device or emulator attached to this machine, and
`flutter devices` offers only Windows and Edge. The debug APK builds. Read the
"What is proved, and by what" section below before trusting any tick.

`DebugExpenseWritten` is gone, as the handoff asked. Deleting it also stranded
`LedgerReady.refusal` and the banner that rendered it — the debug write was the
only thing that ever set them, and `ReviewBloc` carries its own refusal for the
path that still writes. Both went with it.

### Where a Scan lives

Firestore holds Expenses; a Scan and its image are files in
`<documents>/scans/<uid>/`. Not a preference: a Scan is mostly its image, the
image never leaves the phone (ADR-0003), and a Scan whose photograph is on a
different device is not a Scan. Splitting it would also have put capture behind
a network client, which criterion 3 forbids.

One JSON record per Scan beside its JPEG, rather than one index over all of
them. An index half-written by a force-quit loses every Scan; a record does not.
Capture writes the image first and the record second, so the crash window leaves
a stray file nobody reads rather than a Scan with no receipt in it.

### The resize, with a real number

A 4200x2500 photograph, 5.3MB, resizes to 1024x610 and 154KB — **824ms**. That
number is why `resizeForStorage` runs through `compute` rather than inline: most
of a second on the UI isolate is a visible freeze, on the one screen whose whole
promise is that you can photograph the next receipt immediately.

The picker is also asked for 1024 on the long edge, which the platform does far
faster than Dart can. `resizeForStorage` then guarantees the result rather than
redoing it: an image already inside 1024 is handed back byte for byte, un-re-
encoded, because a second JPEG pass costs detail off faint thermal print and
buys nothing. 154KB is about 205,000 characters of base64, against the Worker's
700,000-character limit.

`fitToLongEdge` came out of `planImage` rather than being written next to it, so
the maths the cost model reasons about and the maths the phone performs cannot
disagree. Review caught that the extraction had quietly changed `floor()` to
`round()` in committed cost maths; it floors again.

### What is proved, and by what

Nothing here was proved live. Splitting by what the tests actually establish:

- **Proved by test, through the real code.** The resize (a 2268x3024 photograph
  in, 768x1024 out, through the real decoder), durability across a restart (a
  second `DeviceScanStore` over the same directory finds the Scan and its
  Extraction), abandon removing both files, the Inbox order and filter, the
  count in the app bar, and both photo sources reaching a Scan.
- **Proved structurally, not behaviourally.** Criteria 3 and 10.
  `test/scan/capture_is_the_devices_alone_test.dart` reads the five files a
  photograph passes through and fails if any of them mentions Firestore,
  Firebase, or an HTTP client, and fails if anything in `lib/` deletes a file
  outside the device store. This is the shape ADR-0002's rule is already checked
  in. Both were confirmed to fail when deliberately broken. An absence of
  network calls cannot be asserted behaviourally — it looks identical to a test
  that forgot to make any.
- **Weaker than it reads.** Criterion 2 says "before the capture screen is
  dismissed". `image_picker` hands over the OS camera, which has already
  dismissed itself by the time the app has bytes; what is actually proved is
  that `capture` does not answer until the image and the record are both on disk
  with `flush: true`. Criterion 4 asserts five captures back to back all land as
  distinct Scans — it does not measure that none of them blocked.

### Deliberately ahead of this ticket

Two things in the diff have no producer until 07 or 08, and were built now on
purpose rather than by accident:

- **`ScanState` carries all seven states from the spec's lifecycle diagram**,
  though capture only ever writes `captured`. The Inbox switches exhaustively on
  it, so `inbox_screen.dart` ships one line of copy per state. Ticket 08 owns
  that copy and should replace all four failure lines; they are sentences rather
  than placeholders so that nothing ships reading like a stub in the meantime.
- **`Scan.extraction` and `DeviceScanStore.put`.** The record format is written
  once and read by every later ticket, so the Extraction slot is in it now; a
  round-trip test covers it. Ticket 07 needs `put` to move a Scan through
  `extracting`.

### Notes for whoever picks up 07

- `LedgerStore` is now six methods, four of them the Scan half.
  `FirestoreLedgerStore` implements the Expense half and hands the Scan half
  straight to `DeviceScanStore`. That delegation is the only place the two
  halves meet.
- **`InboxReady` compares Scans by identity**, following `ReviewState`'s
  precedent — an Extraction is not Equatable and a re-read builds fresh objects,
  so a change the Inbox should show can never be swallowed as "no change". The
  cost is a spare rebuild.
- The camera is injected into `WhereMoneyApp` as
  `Future<Uint8List?> Function(PhotoSource)`, so tests hand down bytes and no
  camera fake exists — the line the spec's Testing Decisions draws. It is not a
  third seam: nothing else about it is configurable.
- Widget tests covering capture need `tester.runAsync`, because the resize runs
  on another isolate and the test binding's clock knows nothing about it.
  `waitFor` in `capture_and_inbox_test.dart` is the helper.
- **CONTEXT.md lists "capture" among the words to avoid for *Scan*.** It is used
  here as a verb only — `store.capture`, `ScanCaptured`, `capturedAt` — which is
  how the spec itself writes it ("A capture with no network reaches
  `captured`"). The noun is always Scan.
- iOS got `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`, kept
  honest per the spec. Android needs no manifest change: `image_picker` reaches
  the camera through an intent and the gallery through the photo picker.
