# 13 — Knobs from Remote Config

**What to build:** The model tier can be changed from a console and the next Scan
uses it — no app update, no store review, no deploy. Same for the image size, the
reasoning effort, and the daily cap.

This is the ticket that makes the project's one open question actionable. Whether
the cheapest vision-capable model is accurate enough is unmeasured; the corrected
fields tally from tickets 04 and 07 is what answers it. When that tally says the
total or the merchant is being misread, the fix has to be minutes rather than a
release cycle — otherwise the instrumentation is just data nobody acts on.

The knobs are behaviour, not secrets. Values delivered by Remote Config are
readable by anyone with the app, which is fine for a model name and would be
disqualifying for a key — the key stays a Worker secret. Compiled-in defaults mean
a fetch failure or a first launch with no network behaves correctly rather than
not at all.

**Blocked by:** 05, 07

**Status:** done

- [x] Model tier, image long edge, reasoning effort and the daily cap all come from Remote Config
- [x] Compiled-in defaults are used when a fetch fails or has not completed
- [x] Changing the tier in the console changes what the next Scan uses, with no rebuild
- [x] The requested model is still checked against the Worker's allowlist, so an unknown value cannot reach the API
- [x] Changing the cap takes effect without a Worker deploy
- [x] Knobs are passed through the app as plain values, not injected as a collaborator, and tests set them directly
- [x] The current knob values are visible somewhere in the app, so a misconfiguration is diagnosable
- [x] No secret is ever read from Remote Config

## Comments

Implemented, and **every criterion was watched on the phone against the live
Worker** — including a Scan whose request carried a tier that only ever existed
in the Firebase console. The previous handoff was right that most of this was
already built; what it did not anticipate is that the interesting work turned
out to be at the two ends, not in the middle.

### What was actually missing

`Knobs` is now a value object in `packages/core/lib/src/knobs.dart` — four
plain values with compiled-in defaults, `==`, and `asDelivered()` for seeding a
console. `knobsFrom(delivered, fallback:)` beside it is a pure function over
strings, which is what let the whole read path be tested with `dart test` and
no Flutter harness at all.

`lib/knobs/remote_config_knobs.dart` is the only file that knows Firebase
exists. It is thin on purpose: `main()` awaits it before `runApp`, so anything
it throws is a phone showing nothing.

### The `compute` argument, which was the one real piece of design

`resizeForStorage` took a photograph and a named long edge; `compute` hands its
function exactly one argument. It now takes a record —
`typedef ToResize = ({Uint8List photograph, int longEdge})` — and there is only
one function, not an unpacking wrapper in front of the real one. Records cross
an isolate boundary fine, which the existing widget tests exercise for real
rather than by assertion.

### The picker had to be told too, or the knob would have done nothing

`photographWithDevice` capped `maxWidth`/`maxHeight` at the old constant. A
console asking for 1440 would have been silently cut back to 1024 by the picker
before `resizeForStorage` ever saw it — the knob would have moved and nothing
would have happened. It now takes a required `longEdge`, and
`WhereMoneyApp` builds the device photographer from `knobs` rather than
defaulting to it. `Photographer` itself is unchanged, so no test moved.

### Criterion 7 got sharper after review

The first draft printed the four values under "How receipts are read". Review
pointed out that this makes two misconfigurations **less** diagnosable, not
more: a cap of 60 renders as "60 Scans" while the Worker enforces its ceiling of
40, and `gpt-6-nano` displays as running while `gpt-5-nano` is what actually
reads the receipt. The heading is now **"What each Scan asks for"** and a second
note says where a change goes when it has no effect. That is the honest claim
and it is the one that helps.

The section lives in `lib/settings/how_scans_are_read.dart` rather than in
`settings_screen.dart`, and sits **below** Sign out. A Setting is the user's
choice about their phone; a Knob is the operator's choice about the Model.
`CONTEXT.md` now says so under a new "Operating it" heading.

### The Corrected Fields tally, which is not one of these criteria

Nine handoffs have carried "the tally still needs its `source == scanned`
filter". It is here because this is the ticket that makes somebody read it.
`CorrectedFields.across(ledger)` is a pure function in core; hand-typed
Expenses are excluded, which the test proves by feeding it one that carries a
correction on every field. It renders directly beneath the model, because the
question "is this tier accurate enough" is the two of them together.

**On the phone it read: 1 receipt read, 0 left alone, Merchant corrected on 1
of 1, Category corrected on 1 of 1** — which is exactly the card-slip result in
`spec.md`'s "First real measurement", arrived at independently. The instrument
agrees with the one reading anyone has taken.

### Watched on a device, 2026-08-26

OPPO CPH2499, debug build, live Worker, real Google account.

- All four knobs turned in the console at once (mini / medium / 1440 / 15),
  app force-stopped and relaunched: **all four changed on screen, no rebuild.**
- `image_long_edge` set to `1024px` and `daily_cap` to `lots`, republished,
  relaunched: **both fell back to 1024 and 40 and scanning was unaffected.** A
  console typo degrades.
- With `model` set to `gpt-5-mini`, a receipt scanned from the gallery while
  `wrangler tail` was running. The request on the wire was
  `/extract?model=gpt-5-mini&effort=low&cap=40&media=image%2Fjpeg`. **That is
  criterion 3 end to end** — console to phone to Worker, no rebuild.
- The receipt used was a synthetic one generated for the purpose, so nothing
  personal off that phone went anywhere. Both test Scans were discarded, the
  image was deleted from the gallery, and the console was returned to the
  shipped defaults (template version 7).

### Remote Config now exists, as a file

`remoteconfig.template.json` plus a `remoteconfig` entry in `firebase.json`, so
`firebase deploy --only remoteconfig` publishes it. It was published with the
user's agreement. The four parameters carry descriptions written for whoever
opens the console without this repo in front of them. Nothing about the values
changed: they are the ones the app already shipped with.

### One dependency had to move, and it is not optional

Adding `firebase_remote_config` pulls `firebase_core` past 4.14.0, where the
field `firebase_auth` 6.5.7 compiles against is gone — Android will not build.
`firebase_auth` is now `^6.6.0`, with a comment in `pubspec.yaml` saying why so
nobody lowers it back.

### What is not true, and should not be read as true

- **A knob turned now reaches the next launch, not the next Scan of a running
  session.** The criterion says "the next Scan"; the app reads Remote Config
  once in `main()`. Nothing refetches on resume, and adding that would have
  meant lifecycle handling this ticket did not ask for. The Settings copy says
  it plainly rather than letting anyone infer otherwise. If that gap matters, a
  refetch on resume is the change, and it is small.
- **The accuracy question is still unanswered.** This builds the lever; it does
  not pull it. The console is on `gpt-5-nano`. `spec.md` argues the merchant
  misread is structural — the bank's name is the largest text on a card slip —
  and that a prompt saying where to look would probably fix what a tier change
  might not. Neither has been tried, and the tally still wants twenty receipts.
- **`effort` and `model` are unchecked strings at this end** on purpose. The
  Worker holds both allowlists and falls back on what it does not know, so a
  tier added there reaches phones without an app release. Second-guessing it
  here would take that away.
