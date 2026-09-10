# The sign-in screen in Graphite — handoff for direction A

**Status:** ready-for-agent for the screen. The guest path's behaviour is
needs-info; see "Open decisions". Design canvas:
https://claude.ai/code/artifact/772b3914-cd71-4dc4-8fb9-e36f3d641a16
(the page "Sign-in": three artboards, one per state. "Explorations" holds the
directions and themes that were not chosen and is not being built.)

## Overview

`lib/session/sign_in_screen.dart` is the last screen a new user meets before
the Ledger and the one still drawn in Material's defaults: the name in
`headlineMedium`, the tagline, and a pill `FilledButton` in the middle of the
screen, with the spinner taking the button's place while signing in. Direction
A redraws it in C5 Graphite. The launcher's receipt sits over the name and the
pitch; the two ways in sit at the bottom in the strip Review's commit button
already uses, ranked by shape — Google filled, guest outlined.

Three things change in what the screen says or does. The tagline is new. A
second way in, "Continue as guest", is new, and what it does is not this
ticket's to decide. The failure sentence moves from under the button to above
the buttons. Everything else — the bloc, the gateway, the states, the
restored-session path — stays.

## Layout

One `Scaffold` whose body is a `Column`:

1. `Expanded` — a centred column, `mainAxisSize.min`, horizontal padding 32:
   the receipt mark, 28px, the name, 8px, the tagline. Wrap the column in a
   `SingleChildScrollView` so 200% text scrolls rather than overflows; the
   `Expanded` centres it when it is shorter than the space.
2. The strip. A rule over it in `outlineVariant`, padding 16 horizontal and
   12 vertical, inside `SafeArea(top: false)`. Its contents are a column with
   10px between items: the failure sentence when there is one, the Google
   button, the guest button. Nothing in the strip animates in or out; each
   state is a different set of children at fixed heights, so the strip's
   height only changes when the failure sentence appears.

A 412px phone is the canvas's reference and 390px is the test suite's; nothing
is designed to a breakpoint, and the strip's buttons are full width on both.
There is no app bar, no status bar drawn, and no keyboard on this screen.

## Design tokens used

Every value is a role on the theme or a helper in `lib/settings/themes.dart`.
The hex is what the role resolves to in dark / light, for checking against the
canvas, not for typing into a widget.

| Token | Dark / light | Used for |
| --- | --- | --- |
| `colorScheme.surface` | `#15161A` / `#FAFAFB` | the ground |
| `colorScheme.onSurface` | `#E5E6EB` / `#17181C` | the name; the mark's paper in dark |
| `colorScheme.surfaceContainerLowest` | — / `#FFFFFF` | the mark's paper in light |
| `colorScheme.outline` | `#7E8290` / `#62666F` | the mark's printed lines; its edge in light only |
| `colorScheme.onSurfaceVariant` | `#9A9DA8` / `#5A5E68` | the tagline, the guest button's label |
| `colorScheme.outlineVariant` | `#262931` / `#E3E5EA` | the rule over the strip, the guest button's border |
| `colorScheme.surfaceContainer` | `#1D1F25` / `#F1F2F5` | the guest button's fill |
| `colorScheme.primary` | `#9B8CF0` / `#5B47C4` | the Google button's fill, the mark's total line, the spinner |
| `colorScheme.onPrimary` | `#16131F` / `#F6F4FF` | the Google button's label |
| `colorScheme.error` | from the seed | the failure sentence |
| `atItsWeight(headlineMedium w500, letterSpacing -0.2)` | Public Sans 28/36 | the name |
| `bodyMedium` in `onSurfaceVariant` | 14/20 | the tagline. `bodyMedium` is not muted by the theme, so colour it as `asARow` colours its hint |
| `asScreenName(labelLarge, tracking: 1.2)` | 13 / 700 / tracking 1.2, upper case | both button labels |
| `bodySmall` in `error` | 12/16 | the failure sentence |

Spacing values already named in the code and read from there rather than
retyped: the commit strip's padding and rule from `_Commit` in
`lib/review/review_screen.dart`, the sign-out button's shape from `_SignOut`
in `lib/settings/settings_screen.dart`. Both are private today; see
"Components".

## Components

| Element | Built from | Notes |
| --- | --- | --- |
| Receipt mark | a `CustomPaint`, 72 × 112, from the path data in `android/app/src/main/res/drawable/ic_launcher_foreground.xml` | The one asset on the screen and it is not an asset: the launcher is an Android vector Flutter cannot load, and `flutter_svg` is not a dependency worth adding for one shape. Paint the receipt path with a 3-unit corner radius and the serrated bottom edge as drawn, three rounded lines in `outline` (14 and 20 units wide, 3 tall, radius 1.5, at y 36 / 44 / 52), and the total line in `primary` (20 wide, 4 tall, radius 2, at y 64). The paper is `onSurface` in dark with no edge and `surfaceContainerLowest` in light with a 1-unit edge in `outline`: white paper on a near-white ground vanished without it. Scale the 36 × 56 unit box to 72 × 112 and do not let the text scaler touch it. `ExcludeSemantics`: it is decoration. |
| Name | `Text(words.appName)` | Same key as today. The weight goes through `atItsWeight`, for the reason `themes.dart` gives: a `copyWith(fontWeight:)` on a fetched face sets a number nothing reads. |
| Tagline | `Text(words.signInTagline)` | New copy, both ARB files; see "Strings". Centred, wraps freely. |
| Google button | `FilledButton` in the commit style | `minimumSize: Size.fromHeight(48)`, radius 10, label `cased(words, words.signInWithGoogle)` in `asScreenName(labelLarge, tracking: 1.2)`. This is Review's `_Commit` styling exactly; lift it into `lib/a_form_of_rows.dart` as the one definition of "the one action a screen exists for" and have Review read it from there. Move, do not copy. `onPressed` adds `SignInRequested`. |
| Guest button | `OutlinedButton` in the sign-out style, no icon | Height 48, radius 10, side `outlineVariant`, background `surfaceContainer`, foreground `onSurfaceVariant`, label `cased(words, words.signInAsGuest)` in the same text style. Settings' `_SignOut` draws this shape today; lift it beside the commit style. Outlined and muted because it is the way round the account, not what the screen is for — the reason the Ledger's small FAB is not accent-filled. `onPressed` adds `GuestRequested`. |
| Spinner | `CircularProgressIndicator` at 24, `strokeWidth: 3`, centred in a 48px `SizedBox` | In the Google button's slot, so the strip does not move. `semanticsLabel: words.signInInFlight` — `every_spinner_says_what_it_is_waiting_for_test.dart` fails without it. |
| Failure sentence | `Text(words.signInFailed(detail))` | `bodySmall` in `error`, centred, wraps. Above the buttons, in the strip, because the app says things under or beside what they are about and the buttons are what it is about. |

## States and interactions

The bloc's states are the screen's, unchanged, plus one event.

| State | Google slot | Guest button | Above the buttons |
| --- | --- | --- | --- |
| `SignedOut()` | filled button, enabled | enabled | nothing |
| `SigningIn()` | the spinner | disabled (`onPressed: null`; Material draws it at 38%) | nothing |
| `SignedOut(failure: detail)` | filled button, enabled | enabled | the failure sentence |
| `SessionUnknown()` | — | — | not this screen: `_Opening` in `app.dart` is unchanged |

| Element | State | Behaviour |
| --- | --- | --- |
| Google button | tapped | `SignInRequested`, as today. The bloc emits `SigningIn`, then `SignedIn` through the gateway's stream or `SignedOut` with or without a failure |
| Google button | pressed | Material's filled-button ink, nothing custom |
| Guest button | tapped | `GuestRequested`, a new `SessionEvent`. While the screen is `SigningIn` it is disabled; there is no guest-specific in-flight state |
| Account picker | dismissed | `SignInAbandoned` → `SignedOut()` with no sentence. The user closed it themselves and knows |
| Sign-in | refused | `SignedOut(failure: error.toString())`, the sentence appears, both buttons come back |
| Failure sentence | a second attempt starts | disappears with the `SigningIn` state; it belongs to the attempt that failed |
| Restored session | app opens | `SignedIn` straight from the stream; this screen is never shown. `app_test.dart` pins it |

## Text scaling and language

| Condition | What happens |
| --- | --- |
| Text at 200% | The name and the tagline wrap inside 32px padding; the centred block scrolls if it outgrows the space above the strip. The buttons grow past 48 through `minimumSize` rather than clip their labels. The mark stays 72 × 112. Extend `nothing_clips_at_twice_the_text_size_test.dart` to open the app signed out |
| Chinese | Button labels read as written: `cased` is a no-op for `zh`. "Where Money" stays in Latin, as `signing_in_speaks_chinese_test.dart` already asserts. Both new strings need Chinese |
| A long failure detail | The sentence wraps to as many lines as it needs. It is what the phone said, transcribed, and is never truncated |

## Strings

| Key | English | Chinese | Change |
| --- | --- | --- | --- |
| `signInTagline` | Photograph the receipt. See where the money went. | 拍下收据，看看钱去了哪里。 | changed in both files; the description note stays |
| `signInAsGuest` | Continue as guest | 以访客身份继续 | new in both files |
| `signInWithGoogle`, `signInInFlight`, `signInFailed`, `appName` | — | — | unchanged |

The Chinese lines are the designer's draft and want a native reader before
they ship. Run `flutter gen-l10n` after touching either ARB file.
`signing_in_speaks_chinese_test.dart` asserts the old tagline verbatim and
changes with it.

## Edge cases

- **Abandoned picker.** No sentence, no state change visible; the buttons
  simply come back. Do not treat `SignInAbandoned` as a failure.
- **Sign-in refused with no network.** `app_test.dart` already drives this
  through the fake gateway and expects the detail on screen and the Google
  button back; both still hold, though the finder changes (see "Tests").
- **The strip and a short phone.** The identity block scrolls; the strip
  never does. If the block and the strip together outgrow the screen at 200%,
  the scroll is what gives.
- **Landscape and tablets.** Not designed for. The column centres and the
  buttons stretch; that is acceptable for a screen seen once.
- **Guest while offline.** Depends on the open decision below. Whatever the
  gateway does, a refusal surfaces the same way Google's does: the sentence,
  with the detail.

## Motion

None designed. The spinner is the theme's. State changes swap children at
held heights so nothing jumps; no `AnimatedSwitcher`.

## Accessibility

- **The mark is decoration** and is excluded from semantics. The name and
  the tagline are read as text; nothing else on the screen is a heading.
- **Focus order** is document order: name, tagline, failure sentence when
  present, Google, guest. Nothing is reordered.
- **The spinner says what it is waiting for**, through `semanticsLabel`.
- **The failure sentence is announced** when it appears: wrap it in
  `Semantics(liveRegion: true)` so TalkBack reads it without the user having
  to hunt for what changed. It is also in colour and in position, so nothing
  is said in colour alone.
- **Button names.** `cased` uppercases the label and a `Text`'s semantics
  follow its string, which is what Review's commit button does today. If a
  screen reader spelling out capitals turns out to be a problem, give the
  button a `Semantics(label:)` in sentence case; do it for all three buttons
  at once or none.
- **Contrast.** `onSurfaceVariant` on `surfaceContainer` measures 6.1:1 dark
  and 5.8:1 light for the guest label; `onPrimary` on `primary` is 6.5:1 and
  6.1:1, and is what the Ledger's FAB already ships. The mark's edge in light
  measures 5.5:1 on the ground, and exists for this reason.

## Open decisions

Two things the design cannot settle and the implementer must not guess:

1. **What a guest is.** The Ledger, the receipts directory and the Worker's
   token are all keyed by uid (`StoresFor` in `app.dart`), so a guest needs
   one. The obvious shape is an anonymous Firebase account: the stores work
   unchanged, and the account can later be linked to Google so the Ledger is
   kept. What the user is told they keep and give up, and whether Settings
   grows a "sign in to keep this" row, is an ADR (`docs/adr/`) and a separate
   ticket. Until it lands, `GuestRequested` needs a `SignInGateway` method to
   call — `continueAsGuest()` — and the fake gateway needs to answer it.
2. **Google's G.** Google's sign-in branding guidelines expect their logo on
   the button. The app ships it text-only today and the design keeps that.
   Adding it is a one-line `FilledButton.icon` change once someone has read
   the current guideline and chosen an asset.

## Tests that will need to move with it

- `test/app_test.dart` reaches the button with `find.text('Continue with
  Google')`. The label is now cased, so the finder becomes
  `markSaying('Continue with Google')` from `test/as_drawn.dart`, the same
  reach Settings' sign-out uses. The assertion that the detail appears and
  the button comes back is unchanged.
- `test/session/signing_in_speaks_chinese_test.dart` asserts the old tagline
  in both languages; both strings change. The Chinese button label needs no
  new finder — `cased` leaves it alone.
- `test/every_spinner_says_what_it_is_waiting_for_test.dart` already holds
  the sign-in seam open and asserts `signInInFlight`; the spinner keeps its
  label and moves slots, so the test should stay green.
- `test/nothing_clips_at_twice_the_text_size_test.dart` opens the Ledger
  only. Add a signed-out case.
- `test/session/session_bloc_test.dart` grows a case for `GuestRequested`
  once the gateway method exists.
