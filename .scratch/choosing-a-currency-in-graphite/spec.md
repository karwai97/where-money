# Choosing a currency in Graphite — handoff for Option A

**Status:** ready-for-agent. Design canvas:
https://claude.ai/code/artifact/21fc93b3-cb26-44f8-9f36-b58c3fd43a1e
(page "Option A": the artboards "At rest", "Typing" and "No match"; the switch
above each artboard shows the light palette. Page "Explored" holds the screen
as it is today and options B and C, which are not being built.)

## Overview

`lib/choosing_a_currency.dart` is the one surface still drawn in Material's
defaults — an `OutlineInputBorder` search field with a floating label, plain
`ListTile`s, a `Divider`, `labelLarge` headings — while every screen that opens
it is drawn in C5 Graphite. Option A redraws the sheet in the same hand as
Review and Settings: the search as a labelled cell in a ruled row, the two
groups under filled head strips, codes in the figure face, a hairline between
rows.

What the sheet does is unchanged: a full-height modal sheet, the Home Currency
and the Ledger's currencies first, the rest alphabetically, a search that
matches codes, a code handed back on tap, null on close. Everything the ticket
`.scratch/a-ledger-learns-its-home-currency/issues/02-*.md` decided still
holds — codes alone, no names, no fallback value.

Three things are new:

1. **The current code is marked.** The sheet is told which code it opened
   with and draws a check on that row. Today nothing in the sheet says what
   is already chosen.
2. **The Home Currency is marked** with a tracked HOME mark at the end of its
   row, so the first row of YOURS says why it is first.
3. **The tail's head counts its rows**, using `Head`'s existing trailing
   figure, so the reader knows the list is long before scrolling it.

One string is new: the HOME mark. Everything else reuses the `currency*` keys.

## Layout

One column, full height, as today (`isScrollControlled`, `useSafeArea`,
`FractionallySizedBox(heightFactor: 1)`). A 390px phone is the reference. Top
to bottom:

1. App bar — 52px, rule under
2. Search row — a `Ruled` row holding the label mark and the cell
3. Head — "Yours"
4. Rows — the Home Currency, then the Ledger's currencies, most recent first
5. Head — "All currencies", trailing figure: how many rows follow
6. Rows — everything else, alphabetical

Heads sit directly on the hairline of the row above, with no gap, as Review's
do. The `Divider` between the two groups goes: the second head is the break.
The search row is not scrolled; the two groups scroll under it in a lazily
built `ListView`, as today.

The sheet's top corners are 12px, not Material's 28: pass
`shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top:
Radius.circular(12)))` and `clipBehavior: Clip.antiAlias` to
`showModalBottomSheet`. 12 is the Ledger's small FAB radius; the design has no
28 anywhere.

## Design tokens used

Every value is a role on the theme or a helper in `lib/settings/themes.dart`
or `lib/a_form_of_rows.dart`. The hex is what the role resolves to in dark /
light, for checking against the canvas, not for typing into a widget.

| Token | Dark / light | Used for |
| --- | --- | --- |
| `colorScheme.surface` | `#15161A` / `#FAFAFB` | sheet and app bar ground |
| `colorScheme.surfaceContainer` | `#1D1F25` / `#F1F2F5` | head strips |
| `colorScheme.surfaceContainerHighest` | `#2E323C` / `#D9DBE2` | the search cell's fill |
| `colorScheme.onSurface` | `#E5E6EB` / `#17181C` | codes, what is typed, the screen name, the close icon |
| `colorScheme.onSurfaceVariant` | `#9A9DA8` / `#5A5E68` | the no-match sentence (`bodySmall` carries it) |
| `colorScheme.outline` | `#7E8290` / `#62666F` | label mark, head marks, the HOME mark, the count |
| `colorScheme.outlineVariant` | `#262931` / `#E3E5EA` | the bar's rule, every hairline |
| `colorScheme.primary` | `#9B8CF0` / `#5B47C4` | focused cell edge, caret, the check on the current row |
| `asScreenName(labelLarge)` | 13px / 700 / tracking 1.8, upper case | app bar title |
| `asTrackedMark(labelSmall)` in `outline` — `asAMark` | 11px / 600 / tracking 1.4, upper case | label column, head strips, the HOME mark |
| `asFigures(asAMark)` | JetBrains Mono 11px / 600 / tracking 1.4 | the count in the head (`Head.trailing` does this) |
| `asFigures(bodyMedium w500, letterSpacing 0.4)` | JetBrains Mono 14px / 500 | every code, and what is typed into the search |
| `bodySmall` | 12px, muted | the no-match sentence |

Spacing is already named in `lib/a_form_of_rows.dart` and must be read from
there, not retyped: label column `labelWidth` (88, scaled by the text
scaler), `labelGap` (16), `sayingIndent` (label width + gap, clamped to 120),
`Ruled` row padding 16 / 7 and minimum height 52, cell minimum height 34 with
content padding 10 / 8 and radius 6, `Head` minimum height 30 with padding
16 / 6. Rows in the list use `Ruled`'s numbers exactly — 52 minimum, 16 / 7,
`Hairline` under.

## Components

Everything is built from what `lib/a_form_of_rows.dart` already exports. No
new shared vocabulary; two small extensions to existing pieces.

| Element | Built from | Notes |
| --- | --- | --- |
| App bar | `barNamed(context, words.currencyChooseTitle)` | Title cased upper in `asScreenName(labelLarge)`; the ARB keeps sentence case. Leading is the existing close `IconButton` — `Icons.close`, tooltip `words.currencyClose`, pops null. `barNamed` takes no leading today; give it an optional `leading` rather than composing a second bar. |
| Search row | `Ruled` around a `TextField` decorated with `asARow(context, words.currencySearch)` | The field's name goes in the label column as a mark — "SEARCH CODES", which wraps to two lines in 88px and is accepted, as "LOCK WHERE MONEY" is on Settings. **No `hintText`**: the mark already says what the cell is for, and Review's cells carry a hint only when a Finding asks. Keep `autofocus: true` and `TextCapitalization.characters`. Style the input in `asFigures(bodyMedium w500, letterSpacing 0.4)`: what is typed is a code and sits in the code's face. Wrap in `Semantics(label: words.currencySearch)`, as `_bareText` does on Review — the icon slot is not read out. |
| Head, yours | `Head(words.currencyYours)` | Cased by `Head`. Drawn only when the group has a matching row, as today. |
| Head, all | `Head(words.currencyAll, trailing: '${tail.length}')` | `tail` is the filtered list, so the figure follows the search: 159 at rest with three in YOURS, 9 after typing K. Drawn only when the group has a row. |
| Code row | `InkWell` over a `Ruled`-shaped container, `Hairline` under | Row anatomy is `_ExpenseRow`'s in `lib/ledger/ledger_screen.dart`: `DecoratedBox` with a bottom `outlineVariant` border, `ConstrainedBox(minHeight: 52)`, padding 16 / 7, a `Row`. The code is `Expanded`, in `asFigures(bodyMedium w500, letterSpacing 0.4)`, `onSurface`. Tapping pops the code. Not a `ListTile`: its 56px tile, its own padding and its title style are what the sheet is leaving. |
| HOME mark | `Text(cased(words, words.currencyHome), style: asAMark(theme))` | At the end of the Home Currency's row. New key `currencyHome`, "Home", both ARB files; described as the mark on the Home Currency's row in the sheet. |
| Check | `Icon(Icons.check, size: 18, color: colours.primary)` | At the end of the row whose code equals `current`. When that row is also the Home Currency, the mark comes first, then `labelGap`, then the check. |
| No-match sentence | `Text(words.currencyNoMatch(query), style: bodySmall)` | Under the search row, start-aligned, padded `EdgeInsets.fromLTRB(16 + sayingIndent(context), 12, 16, 0)` — under the cell it is about, at the indent the app says things at. Not centred in the empty screen. |

The public function changes shape:

```dart
Future<String?> chooseACurrency(BuildContext context, {String? current});
```

Review passes `state.extraction.currency`; Settings passes
`state.homeCurrency`. A `current` that is not a code (`???`, `$`, an empty
string) matches no row and nothing is checked. The sheet never corrects it and
never falls back, as the ticket says.

## States and interactions

| Element | State | Behaviour |
| --- | --- | --- |
| Search cell | focused | `primary` 1px edge, caret in `primary`. The sheet opens this way (`autofocus`) with the keyboard up; the list scrolls in the room left, as today |
| Search cell | not focused | transparent 1px edge, same fill — `asARow`'s `enabledBorder`. Reached by dismissing the keyboard |
| Search cell | typed into | the query in the figure face, upper-cased by `TextCapitalization.characters`; filtering is `code.contains(query.trim().toUpperCase())`, unchanged |
| Search cell | cleared | both groups return in full |
| Yours group | nothing matches | head and rows gone; ALL CURRENCIES is the first thing under the search |
| All group | nothing matches | head and rows gone |
| Both groups | nothing matches | the no-match sentence, alone under the search row |
| Code row | at rest | code in `onSurface`, hairline under |
| Code row | pressed | Material's ink, the `InkWell`'s default, nothing custom |
| Code row | is `current` | check at the end, `primary`, 18px; `Semantics(selected: true)` on the row |
| Code row | is the Home Currency | HOME mark at the end, `outline` |
| Code row | both | mark, `labelGap`, check |
| Code row | tapped | pops the code; the sheet's Material dismiss motion |
| Close | tapped | pops null; caller leaves its field alone |
| Scrim | tapped | pops null, as today |

Every code in the list is a row with a `contains` match today and stays
one — nothing here changes the matching, the ordering or what is offered.

## Text scaling and language

There are no breakpoints; there is text scale and there is Chinese.

| Condition | What happens |
| --- | --- |
| Text at 200% | The label column widens with the scaler, the no-match indent stops at 120, rows grow past 52 rather than clip, the head's count is `Head`'s own. Extend `nothing_clips_at_twice_the_text_size_test.dart` to open the sheet |
| Chinese | Heads, the label mark and the HOME mark read as written — `cased` is a no-op. "搜索代码" fits one line in 88px. `currencyHome` needs Chinese; Settings already calls the Home Currency 主货币, and the mark should agree with it |
| Codes | Never translated, never cased: `MYR` is already the word |

## Edge cases

- **The current code is also the Home Currency.** One row, mark then check.
  Common: Review opens with the Home Currency seeded whenever the receipt
  yielded nothing.
- **The current value is not a code.** `???`, `$` or empty: nothing is
  checked. Do not check the Home Currency instead — that would say the app
  had chosen for the reader.
- **A Ledger with only its Home Currency.** YOURS has one row, then the head
  with 161.
- **No Home Currency and an empty Ledger.** No YOURS head; the sheet opens on
  ALL CURRENCIES with 162, as today.
- **A search that empties one group.** The head goes with its rows; the count
  on the surviving head is the surviving rows. `K` leaves nine.
- **A hundred and sixty-two rows.** Stay on `ListView`, never a `Column`: the
  tail is built lazily and the test helper types before tapping for that
  reason.
- **Keyboard up.** The `Scaffold` inside the sheet resizes for the keyboard,
  so the list shortens rather than being covered. Nothing new to do; do not
  set `resizeToAvoidBottomInset: false`.

## Motion

None designed. The sheet keeps `showModalBottomSheet`'s motion, rows keep
Material's ink, the focused edge changes without animation as Review's cells
do.

## Accessibility

- **The search is named.** `asARow` puts the name in `InputDecoration.icon`,
  which screen readers skip; wrap the `TextField` in
  `Semantics(label: words.currencySearch)` as Review's `_bareText` does.
- **The current row says so.** `Semantics(selected: true)` on the row that
  carries the check, so it is announced as selected rather than as a code
  with an icon beside it.
- **The HOME mark is text**, so it is read as written; nothing about the row
  is said in colour or shape alone.
- **Focus order** is document order: close, search, then rows top to bottom.
- **Hit targets.** The close button is Material's 48. Every row is 52 tall and
  full width, and the whole row is the `InkWell`. The search cell is 34 inside
  a 52 row, as Review's are.
- **Close has a tooltip** (`currencyClose`), as today.

## Tests that will need to move with it

The sheet's tests reach into it three ways, and all three change.

- **Rows are found as `ListTile`s.** `test/picking_a_currency.dart` —
  `pickCurrency` taps `find.widgetWithText(ListTile, code)` inside the sheet,
  and `test/review/choosing_a_currency_test.dart` (four places) and
  `test/review/review_speaks_chinese_test.dart` (one) use the same finder
  directly. Change the reach to the row's type — `find.widgetWithText(InkWell,
  code)` inside `inTheCurrencySheet` — and keep asserting on the code's text.
  Change the helper once and the ten `pickCurrency` callers across
  `review_screen_test.dart`, `choosing_a_currency_test.dart`,
  `review_speaks_chinese_test.dart` and
  `ledger/a_ledger_learns_its_home_currency_test.dart` follow.
- **Heads are found in sentence case.** `choosing_a_currency_test.dart` looks
  for `find.text('Yours')` and `find.text('All currencies')`. `Head` cases
  them, so the finders become `'YOURS'` and `'ALL CURRENCIES'` — the same
  move `month_on_screen_test.dart` made for the trend columns, and
  `a_mark_is_cased_by_its_language_test.dart` is the rule. The Chinese test's
  `'全部货币'` is untouched: casing is a no-op there.
- **The search is found by its label text.** `review_speaks_chinese_test.dart`
  asserts `find.text('搜索代码')`. The mark in the label column is that
  string, so it still finds one — but only if the cell has no `hintText`
  saying the same thing, which is the other reason to leave the hint out.

Three assertions are new and belong in `choosing_a_currency_test.dart`: the
row for `current` carries the check and no other row does; the Home
Currency's row carries the HOME mark; the ALL CURRENCIES head shows the tail's
count and follows the search. `no_english_left_test.dart` will fail until
`currencyHome` has Chinese, which is what it is for.
