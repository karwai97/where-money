# Who is signed in, on Settings — handoff for Option B

**Status:** done, on `who-is-signed-in`. Design canvas:
https://claude.ai/code/artifact/46ed2ee0-c21b-433e-b823-26a8f0c37443
(page "Option B": the artboards "Option B · Settings, signed in", "Option B ·
Settings, guest" and "Option B · States"; the page "Not chosen" holds A and C
and nothing on it is being built).

## Overview

Nothing on the phone says whose account the Ledger is under. Settings shows the
phone's Settings, the money's, and a Sign out button, and a user with two
Google accounts has to sign out to find out which one they were in.

Option B puts the answer beside the two buttons that are about it. Under the
table's last hairline, above Sign out (and above "Sign in to keep this Ledger"
for a guest): a 36px disc holding the user's initials, their name at reading
size, and their address with "Google" a tier down. A guest gets an outline
figure in the disc, "Guest", and a line saying there is no account.

It is deliberately not a row in the table. A Setting is a choice about this
phone (`CONTEXT.md`), and the account is neither a choice nor about the phone.
The Daily cap already bends that rule once; this does not bend it twice.

Nothing else on the screen changes, with one exception: the Keep hint loses its
first clause, because the line above it now says that.

## Layout

One column, scrolling, 390px reference. Order, top to bottom:

1. App bar
2. Theme, Language, Lock, Home Currency, Daily cap — as today
3. The 24px gap that already exists
4. **The person** — new
5. "Sign in to keep this Ledger" and its hint — guests only, as today
6. Sign out — as today

The person sits inside the existing 24px gap's margin: 16px horizontal, 16px
between its bottom and the button under it. It is drawn for both an account
holder and a guest; the screen is only reachable signed in, so there is no
third state.

## What is shown

`SignedInUser` carries `uid`, `name`, `email` and `guest`, and nothing else.
There is no photo URL, so nothing is fetched and no placeholder is faked.

| User | Disc | First line | Second line |
| --- | --- | --- | --- |
| Account, with a name | initials of the name | the name | `{email} · Google` |
| Account, no name | first letter of the address | the address | `Google` |
| Guest | outline figure icon | "Guest" | "No account behind this Ledger" |

Google can return an account with no display name, and `name` is nullable for
that reason. An account with no email is not a state Google sign-in produces;
if `email` is null anyway, the second line reads `Google` alone.

**Initials.** The first letter of the first and last whitespace-separated
words of the name, upper-cased; a one-word name gives one letter. Grapheme
clusters, not code units, so a name in Chinese gives its first character rather
than half of one. Put this in a small pure function beside the widget with
tests for: two words, one word, three words, a Chinese name, and no name (falls
to the address's first letter).

## Design tokens used

Every value is a role on the theme or a helper in `lib/settings/themes.dart`.
The hex is what the role resolves to in dark / light, for checking against the
canvas.

| Token | Dark / light | Used for |
| --- | --- | --- |
| `colorScheme.surfaceContainerHighest` | `#2E323C` / `#D9DBE2` | the disc's fill (the cell fill; the disc is a cell with a person in it) |
| `colorScheme.onSurfaceVariant` | `#9A9DA8` / `#5A5E68` | the initials, the second line |
| `colorScheme.outline` | `#7E8290` / `#62666F` | the guest figure's stroke |
| `colorScheme.onSurface` | `#E5E6EB` / `#17181C` | the first line |
| `asTrackedMark(labelSmall)` in `onSurfaceVariant` | 11px / 600 / tracking 1.4, upper case | the initials |
| `atItsWeight(bodyMedium w500)` | 14px / 500 / line-height 20 | the first line |
| `bodySmall` | 12px, muted already | the second line, the Keep hint |

Spacing: disc 36 × 36, radius 18; 12px between the disc and the text; 2px
between the two lines; 16px horizontal margin; 16px under the block. The disc
is fixed at 36 and does not scale with text, for the reason `ReceiptMark`
gives: a mark is not type.

The initials are tracked 1.4 like every other mark, and tracking adds space
after the last letter only, so they sit visibly left of centre in a 36px disc.
Compensate with `padding-left` equal to the tracking (the canvas uses 0.6px
tracking and 0.6px padding; on the theme use 1.4 and 1.4) rather than
dropping the tracking.

## Components

| Element | Built from | Notes |
| --- | --- | --- |
| The person | new private widget in `settings_screen.dart`, `_WhoIsSignedIn` or similar | A `Row` of the disc and a `Column` of two `Text`s. Reads the user off `context.watch<SessionBloc>()`, the way `_guestDrawn` does, so it redraws the moment a guest keeps their Ledger and stops being one. |
| Disc | `Container` 36 × 36, `BoxShape.circle`, fill `surfaceContainerHighest` | Holds a `Text` of the initials in `asTrackedMark(labelSmall)` coloured `onSurfaceVariant`, or `Icon(Icons.person_outline, size: 18)` in `outline` for a guest. `ExcludeSemantics` on the disc: the lines beside it say everything it says. |
| First line | `Text`, `atItsWeight(bodyMedium w500)` in `onSurface` | `maxLines: 2`, `overflow: TextOverflow.ellipsis`. |
| Second line | `Text`, `bodySmall` | `maxLines: 1`, `overflow: TextOverflow.ellipsis`. The address is not translated; the dot and "Google" come from one ARB message with a placeholder. |
| Keep hint | existing `_KeepThisLedger` | Copy change only, below. |

The person answers no tap. There is nothing to open: switching accounts is
signing out and back in, and both buttons for that are directly under it.

## Copy

Sentence case in the ARB files, as always; nothing here is cased at the call
site. New and changed keys, both ARB files:

| Key | English | Chinese |
| --- | --- | --- |
| `settingsSignedInWith` (new, placeholder `email`) | `{email} · Google` | `{email} · Google` |
| `settingsSignedInWithGoogle` (new) | `Google` | `Google` |
| `settingsGuest` (new) | `Guest` | `访客` |
| `settingsGuestNoAccount` (new) | `No account behind this Ledger` | `此账本没有账号` |
| `settingsKeepThisLedgerHint` (changed) | `It goes when this phone does. Signing in keeps it.` | `它会随这部手机一起消失。登录即可保留。` |

"Google" is a product name and is the same in every language, so the two
"Google" strings carry identical values in both files — the same rule the
language names follow. `settingsGuest` is the sign-in screen's word
(`signInAsGuest` is "Continue as guest" / "以访客身份继续"), so the two screens
call a guest the same thing.

## States and interactions

| Element | State | Behaviour |
| --- | --- | --- |
| The person | account with a name | initials, name, `{email} · Google` |
| The person | account without a name | address's first letter, address, `Google` |
| The person | guest | figure icon, "Guest", "No account behind this Ledger"; the Keep button and shortened hint follow |
| The person | guest who has just kept their Ledger | redraws as an account the moment `SessionBloc` emits the linked user, in the same frame `_KeepThisLedger` disappears. Nothing animates; the block simply changes. |
| The person | while a link is in flight (`Linking`) | unchanged — still the guest. The spinner is in the Keep button's slot as today |
| The person | tapped, pressed, focused | nothing. It is not a control and gets no ink and no focus |
| Everything else | — | as today; the sign-out sequence, the guest's confirmation and the erasure are untouched |

## Text scaling and language

| Condition | What happens |
| --- | --- |
| Text at 200% | The disc stays 36px. The name wraps to two lines and then ellipsises; the second line ellipsises at one. The block grows taller and nothing under it is clipped. `nothing_clips_at_twice_the_text_size_test.dart` opens Settings already; the new block is inside what it checks |
| Long name | two lines, then an ellipsis (the "States" artboard shows a 38-character name) |
| Long address | one line, then an ellipsis. Never wrapped: an address broken across lines reads as two addresses |
| Chinese | "访客" and "此账本没有账号" fit on one line each. Initials of a Chinese name are its first character |

## Edge cases

- **A guest who keeps their Ledger.** The uid does not change, so no widget is
  re-keyed and the Ledger under this screen stays loaded. The person and the
  Keep row both watch the session and redraw together. Test this: it is the
  one transition on the screen.
- **No name from Google.** The address takes the first line. Do not fall back
  to a made-up name or to "Account".
- **A name that is only whitespace.** Treat as no name.
- **The Keep hint's first clause is gone.** A reader who lands on the hint
  without reading the line above it still gets the consequence and the remedy,
  which is what the hint is for.

## Motion

None. The theme, the Material ink on the two buttons and the spinner in the
Keep button's slot are as they are today.

## Accessibility

- **One thing to a screen reader.** Wrap the person in `MergeSemantics` so it
  is read as "Kar Wai, kai@example.com · Google" or "Guest, No account behind
  this Ledger" in one go. The disc is `ExcludeSemantics`: the initials and the
  figure are decoration.
- **Not a control.** No `button: true`, no focus node. Focus order is
  unchanged: back, theme, language, switch, currency, then the Keep button for a
  guest, then Sign out.
- **Nothing is said in colour alone.** Whether this is an account or a guest is
  a word on the first line, not the disc's contents.
- **Contrast.** The second line is `bodySmall` in `onSurfaceVariant`, which the
  rest of the screen already relies on. The initials are the same ink on the
  cell fill, the pairing every disabled switch on the screen already draws.

## Tests

- `test/settings/settings_screen_test.dart` — add: an account holder sees their
  name and address; an account with no name sees the address on the first line.
  `FakeSignInGateway.kai` carries a name and `kai@example.com`; add a nameless
  constant beside it rather than mutating `kai`.
- `test/session/a_guest_keeps_a_real_ledger_test.dart:161` asserts the full
  Chinese Keep hint. It changes to the shortened one, and a sibling assertion
  should find `访客` and `此账本没有账号` on the same screen.
- The transition: open Settings as a guest, tap Keep, let the fake gateway link,
  and assert that "Guest" is gone and the name is there without the Ledger
  having been rebuilt (`storesBuilt` stays at 1, the way
  `choosing_a_theme_test.dart` pins it).
- The initials function's unit tests, listed under "What is shown".
- `settings_in_graphite_test.dart` measures how the screen is drawn; add the
  disc's 36px and the 16px margin there if the file's pattern is to pin such
  values, otherwise leave it.
