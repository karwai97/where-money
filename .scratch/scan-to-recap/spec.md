# Scan to Recap — where_money v1

Status: ready-for-agent

## Problem Statement

I spend money in small amounts, many times a month, and I have no idea where it
goes. I have a wallet or a drawer full of receipts. Typing them into an app is
work I will not do, so I don't, and by the end of the month the only number I
have is a bank balance that went down.

The apps that promise to fix this either want me to type everything in anyway,
or they read my bank feed and give me a wall of merchant names with no line
items and no explanation. Neither tells me *what I actually bought* or *what
changed since last month*.

And when an app does read a receipt for me, I have no way of knowing whether it
read it correctly. A tracker that is confidently wrong about a total is worse
than no tracker, because I will trust it.

## Solution

Photograph the receipt. Put the phone away.

The photo is saved immediately and the app is done with you — extraction happens
in the background, so you are never held on a spinner and it works with no
signal. When the Extraction is ready it waits in the Inbox. You open it, see the
receipt image next to the fields the model read, glance at anything the app has
flagged as suspicious, and tap once. It becomes an Expense.

At the end of the month, two charts show where the money went and how that
compares to last month, and a short written Recap says it in words: which
categories moved, what the largest purchases were, which day cost the most.

The load-bearing promise is the flagging. Before you ever see an Extraction, the
app has re-done the receipt's own arithmetic on device — line items against
subtotal, subtotal plus tax plus tip against total, quantity times unit price
against each line — and checked the date for plausibility. It cannot catch
everything, which is exactly why Review is unconditional: the app never commits
an Expense you have not looked at. What it *can* do is tell you where to look.

## User Stories

### Signing in and unlocking

1. As a new user, I want to sign in with my Google account, so that I don't have to invent another password.
2. As a returning user, I want to stay signed in across app launches, so that I don't sign in every day.
3. As a user, I want the app to require my fingerprint or PIN when I open it, so that someone holding my unlocked phone cannot read my spending.
4. As a user, I want the biometric lock to be separate from signing in, so that I understand one protects my data on this device and the other identifies me to the service.
5. As a user, I want to be able to turn the biometric lock off, so that I can trade privacy for convenience if I choose.
6. As a user who has no biometrics enrolled on the device, I want the app to fall back to the device PIN, so that the lock is still available to me.
7. As a user, I want to sign out, so that I can hand the phone to someone else.
8. As a user signing in on a new device, I want my Ledger to be there, so that a new phone is not a fresh start.
9. As a user signing in on a new device, I want to be told that receipt images did not come with me, so that I am not confused by missing photos.

### Capturing a Scan

10. As a user, I want to photograph a receipt from the camera, so that capture is the fastest thing in the app.
11. As a user, I want to pick an existing photo from my gallery, so that I can add a receipt I photographed earlier.
12. As a user, I want the photo saved the instant I take it, so that nothing I have captured can be lost.
13. As a user with no signal, I want capture to work anyway, so that I can scan receipts on a plane or in a basement.
14. As a user, I want to photograph several receipts one after another without waiting, so that clearing a wallet full of them is one sitting rather than ten.
15. As a user, I want the image resized on the device before it is sent, so that I am not uploading megabytes over mobile data for no benefit.
16. As a user, I want to be able to abandon a Scan before reviewing it, so that a blurry photo or a mis-tap does not become a chore.

### The Inbox

17. As a user, I want one place listing every Scan I have not yet Reviewed, so that I always know what is outstanding.
18. As a user, I want to see which Scans are still extracting, so that I know the app is working and not stuck.
19. As a user, I want to see which Scans failed, so that failures are visible rather than silent.
20. As a user whose Scan failed because of the network, I want it retried automatically when I have signal again, so that I don't have to remember.
21. As a user, I want to retry a failed Scan by hand, so that I am not waiting on a background schedule.
22. As a user who has hit the daily Scan limit, I want to be told that plainly and told when it resets, so that I don't think the app is broken.
23. As a user whose photo was not a receipt, I want to be told that and offered to discard it, so that a photo of my cat does not become an Expense.
24. As a user, I want the Inbox count visible from the main screen, so that Scans don't quietly pile up.
25. As a user, I want the Inbox to survive force-quitting the app, so that closing the app is never destructive.

### Reviewing an Extraction

26. As a user, I want to see the receipt image beside the extracted fields, so that I can check the app's reading against the paper.
27. As a user, I want to zoom into the receipt image, so that I can read faint thermal print.
28. As a user, I want every field pre-filled with what the model read, so that Review is confirmation rather than typing.
29. As a user, I want anything the app found suspicious shown at the top with a plain-language explanation, so that I know exactly where to look.
30. As a user, I want to edit any field, so that the app is never stuck with a wrong value.
31. As a user, I want the checks to re-run as I type, so that I can watch a flagged total stop being flagged when I fix it.
32. As a user, I want to change the Category the model chose, so that my own sense of what a purchase was wins.
33. As a user, I want to see why the model chose that Category, so that I can judge whether to trust it.
34. As a user, I want to edit, add, and remove individual Line Items, so that a missed row does not force me to retype the receipt.
35. As a user, I want a one-tap fix when the app suspects the year was misread, so that the most common error costs me one tap rather than a date picker.
36. As a user with a clean Extraction, I want to accept it with a single tap, so that the common case is nearly free.
37. As a user, I want to reject an Extraction outright, so that a bad Scan is one action to dismiss.
38. As a user, I want to leave Review half-finished and come back, so that an interruption does not cost me the work.

### The Ledger

39. As a user, I want a list of my Expenses newest first, so that I can see what I have been spending on.
40. As a user, I want to filter the Ledger by month, so that I can look at a period rather than an endless list.
41. As a user, I want to open an Expense and see its Line Items and its receipt image, so that "what was that 40 at the supermarket" has an answer.
42. As a user, I want to edit a committed Expense, so that a mistake I notice later is fixable.
43. As a user, I want to delete an Expense, so that a duplicate or a refund does not sit in my totals forever.
44. As a user, I want to add an Expense by hand with no receipt, so that cash spending and online purchases are not missing from my picture.
45. As a user, I want to see which Expenses came from a Scan and which I typed, so that I know how much of my Ledger the app produced.
46. As a user, I want an Expense paid in a foreign currency stored with the currency I actually paid in, so that the record is truthful.
47. As a user, I want to be told how many Expenses were left out of my totals because they are in another currency, so that a total I cannot reconcile has a visible explanation.

### Charts and Recap

48. As a user, I want a breakdown of the month by Category, so that I can see the shape of my spending at a glance.
49. As a user, I want a month-over-month trend, so that I know whether things are getting better or worse.
50. As a user, I want the charts and the Recap to agree, so that I can check the words against the picture.
51. As a user, I want a short written Recap of the month, so that I get an explanation rather than a spreadsheet.
52. As a user, I want the Recap for the month I am currently in, not only for closed months, so that it is useful before it is too late to act.
53. As a user, I want the Recap to update after I add or fix an Expense, so that it never contradicts the Ledger it describes.
54. As a user, I want the Recap not to be regenerated every time I open the screen, so that opening a screen does not cost anything.
55. As a user with too few Expenses for a meaningful Recap, I want to be told that instead of given invented insight, so that the app does not fabricate.
56. As a user, I want to see my biggest purchases and my heaviest day of the month, so that the Recap points at something specific I can remember.

### Trust and honesty

57. As a user, I want to know that my receipt photos never leave my phone, so that I am not uploading images of everything I buy.
58. As a user, I want to know the app is not silently committing Expenses it guessed at, so that I can trust the numbers.
59. As the developer, I want the app to record which fields users corrected, so that I have real evidence about whether the cheap model is good enough.
60. As the developer, I want to change the model tier without shipping an app update, so that acting on that evidence takes minutes.
61. As the developer, I want the API key never to be present in the app binary, so that publishing the app does not publish my key.
62. As the developer, I want a per-user daily cap enforced on the server, so that one account cannot run up my bill.

## Implementation Decisions

### Repository shape

`where_money` is a fresh Flutter app. The prototype at `ai_expense_tracker` is
strip-mined and left untouched on disk as a reference; its findings live in this
repo's ADRs, not in copied comments.

Two Dart packages in a pub workspace:

- **the core package** — pure Dart, no Flutter dependency in its pubspec. Holds
  the domain types, the Check, the Rollup, the request and response shapes for
  the Model, and the vision cost maths. The Flutter-free property is enforced by
  the compiler rather than by convention, which is the whole reason for the split
  (ADR-0002's typed-seam argument depends on it).
- **the app** — Flutter, Bloc, Firebase, camera, charts. Depends on the core.

A third deployable that is not a Dart package: **the Worker** (TypeScript), the
only place the OpenAI key exists.

### Carried over from the prototype

Lifted close to unchanged: the Check, the Rollup, the **response-parsing**
functions, the vision and cost maths, the domain model types, the Category and
payment-method taxonomies, and the canned fixtures (which become test fixtures).

Discarded: the entire five-tab prototype shell, and the OpenAI HTTP client —
that logic moves into the Worker.

**Ported to TypeScript, not lifted: the JSON Schema builder and the request
body.** The Worker owns request construction — prompt, schema, and an allowlist
of models — because that is where the key is, and a client that can name its own
model and output budget is a client that can run up the bill. The Worker returns
the raw model response and the **client parses it in Dart**, so the hard-won part
stays in tested pure Dart: the interleaved reasoning items, the refusal block,
and the incomplete status are all parsing traps, and parsing is the half worth
keeping. The schema itself is mechanical to port.

Reimplemented rather than lifted: the Review screen. The prototype's editor
proved the *pattern* — re-run the Check on every keystroke, and record each edit
by field name — and that pattern is the requirement. The widget code is not.

### The Worker contract

Two endpoints, both requiring a Firebase ID token in the `Authorization` header.

- **extract** — takes an already-base64-encoded image and the Knobs the client
  is running with; returns an Extraction, or a typed failure.
- **recap** — takes a Rollup as JSON; returns prose.

The Worker verifies the ID token against Google's signing certs, caching them in
the isolate. It reads and increments a per-user daily counter in Workers KV and
refuses past the cap with a distinct status the client can render as "resets
tomorrow" rather than as an error.

**The client base64-encodes; the Worker does not.** The free plan allows 10ms of
CPU per request. Awaiting `fetch` is exempt, so the model round trip is free, but
encoding a 200KB image is not. The Worker forwards the request body without
parsing or re-encoding it. This is a hard constraint, not a preference.

### Failure taxonomy

The prototype established that the Responses API fails in ways that are not HTTP
errors, and each needs its own user-visible outcome:

- The output array interleaves reasoning items with message items, so the text is
  never simply the first element — every message's content is walked.
- A **refusal** arrives as a refusal content block with a 200 status. It must be
  checked for before any text is trusted.
- If reasoning consumes the whole output budget, the response is status
  `incomplete` with **no text at all** — distinct from truncated JSON.

Plus the client-side and Worker-side cases: no network, cap reached, token
rejected, not-a-receipt.

Every one of these is an Inbox state with its own copy. None of them is a modal
error dialog.

### Schema construction

Strict mode constrains the schema in ways that are not obvious and are easy to
"fix" wrongly later. Recorded here because a future reader will otherwise try
`anyOf`:

- every object needs `additionalProperties: false`
- **every** property must appear in `required`
- the root cannot use `anyOf`
- therefore optionality is expressed as a **type union**, not an omitted key:

```jsonc
// From the prototype. Idiomatic elsewhere would be an anyOf with a null
// branch; here that is rejected outright.
"subtotal": { "type": ["number", "null"] }
```

The date-format keyword on the purchase date is used but is not load-bearing — if
strict mode rejects it, it drops to a plain nullable string.

### Scan lifecycle

A Scan is durable from the moment the shutter fires. Extraction is a separate,
retryable step. The states, which the Inbox renders directly:

```
captured ──▶ extracting ──▶ extracted ──▶ (Review) ──▶ committed
                 │                              │
                 ├──▶ failed ──(retry)──▶ extracting
                 ├──▶ capped ──(tomorrow)─▶ extracting
                 └──▶ notReceipt ──▶ discarded
```

`captured` requires no network and cannot fail. Nothing deletes a Scan except the
user.

### Review is unconditional

The Check produces Findings at ok, warn, or fail, and can conclude that an
Extraction is arithmetically self-consistent. That does **not** authorise a silent
commit. The prototype's most instructive failure was a misread year — a valid ISO
date in the past that satisfied every arithmetic check and was wrong. A clean
Check therefore earns a *pre-filled form and one tap*, not a bypass.

Three lanes, two of which end at the same screen with different framing:

- **clean** — fields pre-filled, one tap to accept
- **flagged** — same screen, Findings pinned above the fields
- **not a receipt** — offered for discard, not for Review

The Check keeps the prototype's behavioural heuristics, not just its arithmetic: a
date more than 60 days old is flagged, and a date within a month of exactly one
year ago says so explicitly, because on a freshly photographed receipt that is far
more likely a digit error than a genuinely old receipt. Cheap heuristics grounded
in user behaviour catch things the model cannot self-report.

### Corrected Fields

Every edit made during Review is recorded by field name and stored on the
committed Expense. This is not telemetry decoration — it is the only measurement
that will ever answer whether the nano tier is accurate enough, and it is the
input to the Remote Config model switch. A field the user has corrected no longer
counts as needing review, since it has just been reviewed by the only authority
that matters.

### Persistence

Firestore is the source of truth for the Ledger, laid out flat as one Expense
document per user. Rollups are **computed on device in pure Dart**, never
denormalised into Firestore — one truth, and the Rollup stays deterministic and
testable.

Nothing above the repository sees an untyped document. The repository is the only
place Firestore's shape is known.

Images are device-local, at the size that was actually uploaded, with the path
recorded on the Expense. Security rules restrict every path to its owning user.

### Recap caching

A Recap is a pure function of a Rollup, so it is cached against a **hash of the
Rollup**. Opening a month with an unchanged hash costs nothing; adding or fixing
an Expense changes the hash and the next open regenerates. This is what makes the
current, still-changing month work correctly, and it makes staleness structurally
impossible rather than a thing to remember.

Below a minimum number of Expenses, no Recap is requested at all and the screen
says so. The app does not ask a model to find meaning in three receipts.

### Knobs

Model tier, image long edge, reasoning effort, and the daily cap come from Remote
Config with compiled-in defaults, and are passed through the app as a plain value
object rather than injected as a collaborator. They are behaviour knobs, not
secrets — the key is a Worker secret and is never in the client, in Remote Config,
or in a build-time define.

Default image long edge is ~1024px. The prototype measured that a portrait
receipt saturates the model's patch budget at roughly 1440px, so asking for 1568,
2576, or the phone's full resolution bills identically while costing real upload
bandwidth.

### State management

Bloc, chosen over Riverpod deliberately. Async-heavy states — a Scan in flight, a
Firestore stream, a Recap generating — each get explicit states rather than
ad-hoc flags. The prototype's single 393-line `ChangeNotifier` is the anti-pattern
being avoided.

### Platforms

Android is built and tested. The iOS project is kept configured and honest but is
not built or claimed to work — there is no Mac in the development environment. No
web build: the camera pipeline is the point, and web is where it is weakest.

## Testing Decisions

### What makes a good test here

A test states something a user or an operator would notice, and says nothing about
how the code is arranged. "A receipt whose line items don't sum to the subtotal is
flagged rather than accepted" is a good test. "The Check calls the line-item
comparison helper" is not — it will break on a refactor that changes nothing
observable.

Concretely, for this project: assert on Findings, on the state a Scan lands in, on
the Expense that ends up in the Ledger, on the numbers in a Rollup, and on which
fields got recorded as corrected. Never on call counts, private methods, or widget
trees.

### Two seams, and nothing else faked

- **ModelGateway** — the boundary to the Worker. Its fake returns canned
  Extractions and canned Recaps, and can be told to produce each member of the
  failure taxonomy: refusal, incomplete, cap reached, token rejected, network
  dead, not-a-receipt.
- **LedgerStore** — the boundary to persistence. Its fake is in-memory, holding
  Expenses, Scans, and image bytes.

Deliberately **not** seams. Knobs is a value object, so tests pass values. Auth
collapses into store construction, since the only thing the domain wants from it
is a user identity. The camera sits *above* the tested surface — the capture
widget's entire job is to produce bytes and hand them down, so tests inject bytes
and no camera fake exists.

A single fat interface over the whole outside world was considered and rejected: it
would force every test to fake network *and* storage even when it cares about one,
and the fake becomes a second implementation of the app.

### What gets tested where

**No seam needed — pure functions over values.** The bulk of the test suite, and
the cheapest tests in it, run in the core package with `dart test` and no Flutter
harness at all:

- The Check, against fixtures: clean receipts pass; arithmetic contradictions are
  found; a future date is rejected; a date a year old produces the year-misread
  Finding specifically; enum violations are caught. This module is the project's
  main risk reduction, so it gets the most thorough tests.
- Response parsing, against recorded wire shapes: reasoning items interleaved
  before the message, a refusal block, an incomplete status with no text,
  well-formed output. Each maps to its distinct outcome.
- Schema construction: every object closed, every property required, no `anyOf` at
  the root, optional numbers emitted as type unions.
- The Rollup: category totals, month-over-month deltas, top purchases, heaviest
  day, and the exclusion of non-Home-Currency Expenses with a correct excluded
  count.
- The vision cost maths, which is entirely offline and already has known-good
  numbers from the prototype to assert against.

**Across the seams — Bloc tests.** Given a faked gateway and store, assert the
sequence of states and the resulting Ledger:

- A capture with no network reaches `captured` and stays there, then extracts when
  the gateway recovers.
- Each failure-taxonomy member produces its own Scan state, and none of them loses
  the image.
- A clean Extraction still requires an accept before an Expense exists.
- Editing a field during Review clears the corresponding Finding and records the
  field as corrected.
- Committing writes exactly one Expense, with the corrected-field list attached.
- A Rollup whose hash is unchanged does not ask the gateway for a Recap; one whose
  hash changed does.
- Below the minimum Expense count, no Recap is requested.

**Worker tests.** A request with no token, a bad token, and a good token past the
cap each produce their distinct response. Run against the local dev runtime, not
against OpenAI.

### Prior art

There is none in this repo — it has no code yet. The nearest thing is the
prototype's fixture file, whose canned clean Extraction and canned deliberately
flawed Extraction were what proved the Check works. Those two fixtures move over
and become the backbone of the Check's tests, alongside a seeded month of Expenses
for the Rollup.

The first tests written therefore *set* the prior art, and should be written to be
copied: fixtures as named constants, one behaviour asserted per test, test names
that read as sentences about receipts rather than about classes.

## Out of Scope

- **Sharing, households, and multi-user ledgers.** One user, one Ledger, no owner
  field, no splitting. The schema should not actively prevent adding an owner
  later, but nothing is built for it.
- **FX and multi-currency aggregation.** No rates provider, no historical rates,
  no rounding policy. Foreign Expenses are stored truthfully and excluded from
  aggregation, and the exclusion is shown.
- **Bank feeds, card imports, and statement parsing.** The receipt is the input.
- **Budgets, limits, goals, and alerts.** The app describes spending; it does not
  police it.
- **Recurring-transaction and subscription detection.**
- **Export**, in any format.
- **User-defined Categories.** The taxonomy is closed by design (ADR-0005).
- **Cloud backup of receipt images.** Device-local only (ADR-0003).
- **iOS builds**, and any claim that iOS works.
- **A web build.**
- **Store submission**, review, or support processes.
- **App Check and a global spend circuit breaker.** Considered and deferred; the
  per-user cap ships and the global counter is left as a marked gap, because the
  worst case is bounded by account count and Google Sign-In makes accounts free.
- **Non-English receipts** as a supported case. They may work; nothing is done to
  make them work and nothing is measured.

## Further Notes

### The unresolved question this app is instrumented to answer

Extraction accuracy at volume is unknown. The prototype managed exactly one live
scan, and it read the year wrong. Cost is settled and is not the constraint —
under a cent per user per month on the nano tier — so the only open question is
whether the cheapest vision-capable model is *accurate enough*.

That is why the Corrected Fields tally exists and why Review is unconditional.
After twenty or so real receipts, the tally is the answer: if the corrections are
dates and merchant capitalisation, nano is fine. If the total starts appearing,
switch tiers in Remote Config. A wrong year is annoying; a wrong total is
disqualifying.

### Other first-live-call unknowns

- **Latency.** The decoupled Scan of ADR-0004 was chosen partly so that a slow
  round trip degrades into a wait in the Inbox rather than a spinner. If it turns
  out fast, nothing needs to change.
- **Whether the nano tier accepts a reasoning-effort parameter at all.** It is
  documented for larger families; the nano tier's supported subset is not stated
  alongside it. If a request is rejected on it, the knob has an omit setting that
  leaves the key out entirely.
- **Whether the date-format keyword survives strict mode.** If not, it becomes a
  plain nullable string. Nothing depends on it.

### Things a reader will want to argue with

Three decisions look wrong at first glance and are deliberate. Each has an ADR.

- **Firestore holds the amounts, but images stay on the phone.** This looks
  inconsistent. It is a billing constraint that turned out to be the better
  design: Cloud Storage requires a paid plan, and Review needs the image locally
  anyway.
- **Review happens even when every check passes.** This looks like friction that
  could be optimised away. It is the one thing standing between the user and a
  silently wrong total, and it is also the accuracy instrument.
- **The proxy is on Cloudflare while everything else is Firebase.** Two platforms
  looks like an accident. Cloud Functions cannot make outbound calls without a
  billing account; the Worker can, for free, with no cold start.

## First real measurement, 2026-08-25

One receipt is not a measurement, and the tally still needs twenty or so. But
the instrument has now produced its first reading, on a physical device against
the live Worker and the nano tier, and it is worth writing down because the
failure it found is not the one this spec predicted.

The receipt was a **card terminal slip** — a bank's payment confirmation for a
clinic visit, RM 143.00.

| Field | What the Model read | Correct? |
|---|---|---|
| Total | 143.00 | yes |
| Currency | MYR, from "RM" | yes |
| Date | 2025-07-09, from "09JUL2025" | yes |
| Payment method | card | yes |
| Line items | none | yes — a card slip has none |
| **Merchant** | **PUBLIC BANK** | **no — the clinic is named directly beneath the bank's logo** |
| **Category** | **fees_charges**, "Card transaction payment." | **no — follows from the merchant** |

Two corrections, and **the total was right**, which is the disqualifying case
this spec named and it did not happen.

But the merchant error is not the "dates and merchant capitalisation" this spec
guessed nano would get wrong. It is **systematic**: on any card terminal slip,
the largest and most prominent name is the acquiring bank, and the merchant is
smaller text underneath. A tier change might not fix that; a prompt that says
where to look on a card slip probably would. **Neither has been tried.**

The Check also produced a **false positive**: the year-misread heuristic fired
on a receipt genuinely a year old. That is the heuristic working as designed —
the spec argues for it explicitly — and the copy hedges correctly ("usually
means", "likely value") rather than asserting. It was ignored during Review,
which is the right answer and is why Review has the last word. Worth knowing
that the first real receipt tripped it.

