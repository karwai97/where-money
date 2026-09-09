# Settings in Graphite — handoff for Option A

**Status:** ready-for-agent. Design canvas:
https://claude.ai/code/artifact/7096f5f2-b3e9-4a26-a5a1-ad66c6589537
(the artboards "Option A · Form rows" and "Option A · Light"; B and C are not
being built).

## Overview

Settings is the one screen still drawn in Material's defaults — `ListTile`,
`DropdownButton`, `SwitchListTile`, `Divider` — while the Ledger and Review
are drawn in C5 Graphite. Option A redraws it in Review's hand: the setting's
name in the tracked label column, its value in a filled cell beside it, the
sentence about it indented under the cell, a hairline between rows, and a
filled head strip over each group.

Nothing about what the screen says or does changes. Same five settings, same
copy, same cubit calls, same sign-out sequence. Two strings are new: the two
section heads.

## Layout

One column, scrolling. A 390px phone is the reference; every width below is
either the screen's or a value already in the code, so nothing is designed to
a breakpoint. The order, top to bottom:

1. App bar
2. Head — "This phone"
3. Theme
4. Language
5. Lock Where Money
6. Head — "The money"
7. Home Currency
8. Sign out

Heads follow the previous row's hairline directly, with no gap, as Review's
do. Sign out sits 24px under the last hairline.

## Design tokens used

Every value is a role on the theme or a helper in `lib/settings/themes.dart`.
The hex is what the role resolves to in dark / light, for checking against the
canvas, not for typing into a widget.

| Token | Dark / light | Used for |
| --- | --- | --- |
| `colorScheme.surface` | `#15161A` / `#FAFAFB` | screen and app bar ground |
| `colorScheme.surfaceContainer` | `#1D1F25` / `#F1F2F5` | head strips, sign-out fill |
| `colorScheme.surfaceContainerHighest` | `#2E323C` / `#D9DBE2` | cell fill |
| `colorScheme.onSurface` | `#E5E6EB` / `#17181C` | values, screen name |
| `colorScheme.onSurfaceVariant` | `#9A9DA8` / `#5A5E68` | supporting sentences, sign-out label (`bodySmall` carries it already) |
| `colorScheme.outline` | `#7E8290` / `#62666F` | label marks, head marks, dropdown arrow, chevron |
| `colorScheme.outlineVariant` | `#262931` / `#E3E5EA` | every rule and hairline, sign-out border |
| `colorScheme.primary` | `#9B8CF0` / `#5B47C4` | switch track when on, focused cell edge |
| `colorScheme.onPrimary` | `#16131F` / `#F6F4FF` | switch thumb when on |
| `asScreenName(labelLarge)` | 13px / 700 / tracking 1.8, upper case | app bar title |
| `asScreenName(labelLarge, tracking: 1.2)` | 13px / 700 / tracking 1.2 | sign-out label |
| `asTrackedMark(labelSmall)` in `outline` | 11px / 600 / tracking 1.4, upper case | label column, head strips |
| `atItsWeight(bodyMedium w500)` | 14px / 500 | dropdown values |
| `asFigures(bodyMedium w500, letterSpacing 0.4)` | JetBrains Mono 14px / 500 | the currency code |
| `bodySmall` | 12px, muted | every supporting sentence |

Spacing values that are already named in `review_screen.dart` and must be
read from there rather than retyped: label column `_labelWidth` (88 scaled by
the text scaler), label-to-cell `_gap` (16), the indent under a row
`_sayingIndent` (label width + gap, clamped to 120), row padding 16 / 7, row
minimum height 52, cell minimum height 34, cell content padding 10 / 8, cell
radius 6, head minimum height 30 with padding 16 / 6.

## Components

The screen is built from Review's row vocabulary, which today is private to
`lib/review/review_screen.dart`. It has to be lifted before it can be shared.
Where it lands is the implementer's call; the precedent is
`lib/choosing_a_currency.dart`, top-level because Review and Settings both
read it, and `lib/on_screen.dart` for the same reason. The pieces to lift are
`_asARow`, `_cell`, `_mark`, `_Ruled`, `_Hairline`, `_Head`, `_Closed`,
`_Chosen`, `_Focused`, `_labelWidth`, `_sayingIndent` and `_gap`. Move them,
do not copy them: two definitions of a cell will drift.

| Element | Built from | Notes |
| --- | --- | --- |
| App bar | the theme's `AppBar`, title as Review's `_barNamed` | `settingsTitle.toUpperCase()` in `asScreenName(labelLarge)`. Upper case is typography, not wording; the ARB keeps sentence case. Leading is the default back arrow. |
| Head strip | `_Head(text)` | Two new keys, `settingsSectionPhone` "This phone" and `settingsSectionMoney` "The money", both ARB files. Cased at the call site, a no-op in Chinese. |
| Theme row | `_Ruled` around `_Closed` | `name: 'theme'`, options `ThemeMode.values` in the order system, light, dark, copy from the three existing `settingsTheme*` keys. No `marked`. `onChosen` calls `SettingsCubit.chooseTheme`. Hairline under. |
| Language row | `_Ruled` around `_Closed` | `name: 'language'`, options `languages` from core in their own order, copy via the existing `_named`. `onChosen` calls `chooseLanguage`. |
| Lock row | `_Ruled` holding a column: the label-and-switch pair, then the sentence | Label `settingsLock` as a mark in the 88px column, `maxLines: 2` as `_asARow` allows — it wraps to two lines in English and that is accepted. Value column holds a bare Material `Switch` aligned to the end; there is no cell fill behind it, a switch is its own shape. Sentence under the pair at `_sayingIndent`, `bodySmall`, 2px below the pair. |
| Home Currency row | `_Ruled` holding a column: `_Chosen`, then two sentences | `_Chosen` is the exact currency cell Review draws: code in the figure face, `chevron_right` 16 in `outline`, whole row an `InkWell` that opens `chooseACurrency`. Under it at `_sayingIndent`: the provenance line, then `settingsHomeCurrencyGoverns`. 6px between the cell and the first sentence, 0 between the two. |
| Sign out | `OutlinedButton.icon` | Height 48, horizontal margin 16, radius 10, side `outlineVariant`, background `surfaceContainer`, foreground `onSurfaceVariant`. Icon `Icons.logout` at 18, 10px gap, label `settingsSignOut.toUpperCase()` in `asScreenName(labelLarge, tracking: 1.2)`. The shape is the Ledger's small FAB stretched to the Review commit button's height: outlined and muted because signing out is a way out of the screen, not what the screen is for. |

`_Closed` already handles what would otherwise bite here: `isExpanded` so the
cell never takes the widest option's width, and the `ValueKey('$name:$value')`
that reseeds it when the value changes underneath it.

## States and interactions

| Element | State | Behaviour |
| --- | --- | --- |
| Theme / Language cell | at rest | fill `surfaceContainerHighest`, transparent 1px edge, arrow in `outline` |
| Theme / Language cell | focused | edge `primary`; `_asARow`'s `focusedBorder` does this |
| Theme / Language cell | tapped | Material's dropdown menu, as today; the chosen item is written through the cubit and the cell reseeds |
| Lock row | availability not yet read | label only — no switch, no sentence. Today's screen draws a bare `ListTile`; keep the row at its 52px minimum so nothing jumps when the switch arrives |
| Lock row | `biometrics` | switch enabled, `settingsLockBiometrics` under it |
| Lock row | `deviceCredential` | switch enabled, `settingsLockDeviceCredential` under it |
| Lock row | `none` | switch off and disabled (`onChanged: null`), `settingsLockUnavailable` under it. A switch that cannot be turned on is still drawn: the sentence says why |
| Switch | on | track `primary`, thumb `onPrimary` (Material 3's switch on this scheme; nothing measured on the canvas) |
| Switch | off | Material 3's unselected switch on this scheme: `surfaceContainerHighest` track with an `outline` edge and thumb |
| Home Currency cell | has a currency | code in the figure face, chevron |
| Home Currency cell | none yet | empty cell, chevron still drawn; provenance line reads `settingsHomeCurrencyNone` |
| Home Currency provenance | learned and unchanged | `settingsHomeCurrencyInferred`. Decided by comparing against `learnableCurrency(expenses)` exactly as the screen does today — do not change that test, the handoff at `where_money-handoff.md` explains why |
| Home Currency provenance | chosen by the user | no provenance line; only the governs sentence |
| Home Currency row | tapped | `chooseACurrency`, then `chooseHomeCurrency` if a code came back. The `InkWell` is `_Chosen`'s; its focused edge follows `_Focused` |
| Sign out | tapped | pop, then `SignOutRequested` on the session bloc — the order today's `_signOut` uses, kept |
| Sign out | pressed | Material's outlined-button ink, nothing custom |

No loading spinner anywhere on this screen, and none is wanted: the settings
are seeded before the first frame, and the Lock's one asynchronous read is
covered by the row above.

## Text scaling and language

There are no breakpoints; there is text scale and there is Chinese.

| Condition | What happens |
| --- | --- |
| Text at 200% | The label column widens with the scaler (`_labelWidth`), the indent under a row stops at 120 (`_sayingIndent`'s clamp), rows grow past 52 rather than clip. `nothing_clips_at_twice_the_text_size_test.dart` should be extended to open Settings |
| Chinese | Heads and marks read as written — `toUpperCase()` is a no-op. "锁定 Where Money" and "主货币" fit one line each in the 88px column. Both new head keys need Chinese |
| Long option copy | The dropdown is `isExpanded`; a long label ends in an ellipsis inside the cell, never a stripe |

## Edge cases

- **Two-line labels.** "Lock Where Money" and "Home Currency" wrap in 88px.
  The row's minimum height absorbs it. This is the tradeoff the canvas note
  states; it was accepted rather than widened, because widening the column
  moves Review's cells too.
- **No Home Currency yet.** The cell is empty rather than showing a dash or a
  placeholder — a code the app does not have is not a thing to draw, and the
  sentence under the cell says what will set it.
- **A phone with no screen lock.** The switch is drawn disabled and off. It
  must not be hidden: the sentence under it is how the user finds out what to
  do in Android settings.
- **The Lock read never returning.** The row stays label-only. Nothing else on
  the screen waits on it.

## Motion

None designed. The theme change itself animates through `MaterialApp`'s
default theme transition, the dropdown and the currency sheet use their
Material motion, and the ink on the sign-out button is the theme's.

## Accessibility

- **Every field still has its name.** `_asARow` puts the name in the
  `InputDecoration.icon` slot, which is not read out. `_Closed` and `_Chosen`
  already wrap themselves in `Semantics(label:)`. The Lock row is new
  composition: wrap the label, the switch and the sentence in one
  `MergeSemantics` so the switch is announced with its name and its state, and
  the sentence is read with it.
- **Focus order** is document order: back, theme, language, switch, currency,
  sign out. Nothing is skipped and nothing is reordered.
- **Hit targets.** The switch is Material's 48px. `_Chosen`'s ink covers the
  whole row. The dropdown cells are 34px tall inside a 52px row, the same as
  Review's; if that is judged too small here, make the whole `_Ruled` row the
  tap target rather than growing the cell.
- **Nothing is said in colour alone.** The switch's state is in its position
  and its semantics, the focused edge has the cursor beside it, and the
  currency's provenance is a sentence.

## Tests that will need to move with it

`test/settings/choosing_a_theme_test.dart` and
`choosing_a_language_test.dart` reach the menus through
`find.byType(DropdownButton<...>)`. `_Closed` draws a `DropdownButtonFormField`,
so those finders change to `DropdownButtonFormField<ThemeMode>` and
`DropdownButtonFormField<String>` — the house rule is to reach a control by its
type and assert on readable text, so only the reach changes.
`settings_screen_test.dart` should be read before touching the Lock row: any
finder on `SwitchListTile` becomes `Switch`, and the label is now a sibling
rather than the tile's title. `choosing_a_theme_test.dart` also asserts
`storesBuilt` stays at 1 across a theme change; nothing here touches the
scope, so it should stay green without edits.
