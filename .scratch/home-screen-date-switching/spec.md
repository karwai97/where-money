# Choosing a month on the Ledger

Design canvas: https://claude.ai/code/artifact/883240ac-f967-495b-a95e-cc1cf18551fb
(page "Design" is the decision; page "Options explored" is what was not chosen).

## The problem

The six-bar trend under the Ledger's total is the only way to change month.
It moves one month per tap, and anything older than the window means tapping
the edge column and waiting for the window to slide along. There is no way to
name a month and go to it, and no way back to today once you have wandered.

## The decision

Two additions to `LedgerScreen`, nothing removed:

1. **The month badge in the header becomes a button.** Tapping it opens a
   bottom sheet showing one year at a time: its twelve months, each with what
   it cost. Tapping a month moves the Ledger there and closes the sheet. Any
   month is two taps away.
2. **A pill returns to today.** Once the reader has left the month the app
   was opened in, a pill floats at the bottom of the list and takes them
   straight back. It is not shown on the current month.

The trend stays exactly as it is. It remains the one-tap way to the months
next door; the sheet is for everything further.

## Vocabulary

Terms as `CONTEXT.md` and the code use them. A **month** is a `Rollup`. The
**opened month** is `_opened` in `LedgerBloc`: the month the app was started
in, and the ceiling nothing can move past. The **month on screen** is
`LedgerReady.rollup`.

## Layout and tokens

Everything is read off the theme in `lib/settings/themes.dart`. Values are
given for the dark brightness so the artboard can be checked against them;
the code uses the role, never the hex.

| Role | Dark | Used here for |
| --- | --- | --- |
| `colorScheme.primary` | `#9B8CF0` | badge, chevron, the showing month's cell, pill label, focus rings |
| `colorScheme.onPrimary` | `#16131F` | text on the showing month's cell |
| `colorScheme.surface` | `#15161A` | month cells on the sheet |
| `colorScheme.surfaceContainer` | `#1D1F25` | the sheet, the pill |
| `colorScheme.onSurface` | `#E5E6EB` | month labels with spending, the year |
| `colorScheme.onSurfaceVariant` | `#9A9DA8` | cell totals, the drag handle (at 40%), labels of months with nothing in them |
| `colorScheme.outline` | `#7E8290` | labels of future months |
| `colorScheme.outlineVariant` | `#262931` | the pill's border, matching the small FAB |

Type goes through the helpers in `themes.dart`. Never `copyWith(fontWeight:)`
without them; the weight will not resolve (see the handoff note on
`google_fonts`).

| What | Style |
| --- | --- |
| Badge label, unchanged | `atItsWeight(labelSmall.copyWith(color: primary, fontWeight: w600, letterSpacing: 1.1))`, `cased()` |
| Year in the sheet | `asFigures(titleSmall)` (JetBrains Mono 14/20, w500) |
| Month label in a cell | `asTrackedMark(labelSmall)`, `cased()` |
| Total in a cell | `asFigures(bodySmall)` with tabular figures, muted by the theme |
| Pill label | `asScreenName(labelLarge, tracking: 1.2)`, `cased()`: the button-name style |

### The badge button

- A `TextButton` around the existing badge text and a 14px `Icons.expand_more`
  in `primary`, 4px apart. Padding 8px horizontal, 6px vertical, so the
  visible button is 28px tall and the header keeps its 132px.
- `tapTargetSize: MaterialTapTargetSize.padded` gives it a 48px hit area
  without changing layout. Do not grow the row for the target.
- Shape: rounded rectangle, radius 6. Overlay: `primary` at 12% pressed,
  8% hovered (Material defaults for a text button in `primary`).
- The header `Row` keeps `CrossAxisAlignment.baseline`; the button's label
  baseline lines up with the total as the badge does today.
- The chevron is drawn on every month, including the opened one, so the way
  into the sheet looks the same wherever the reader is.

### The sheet

`showModalBottomSheet` with `isScrollControlled: true` and `useSafeArea:
true`. The default 9/16 height cap would clip the grid on a small phone in
landscape, so the content is wrapped in a `SingleChildScrollView`.

- Background `surfaceContainer`, the Material 3 shape (28px top radii),
  `showDragHandle: true`. Scrim is Material's default (32% black).
- Horizontal padding 16. Bottom padding 28 plus the safe area.
- **Year row**, centred, 12px below the handle: `IconButton` with
  `Icons.chevron_left`, the year with a minimum width of 64 and centred text,
  `IconButton` with `Icons.chevron_right`. Icon buttons are Material's 48px
  targets. The year is `DateFormat.y(locale)`, so Chinese reads `2026年`.
- **Grid**, 12px below the year row: three columns, four rows, 8px gaps,
  months in calendar order left to right, top to bottom. Build it as a
  `Column` of `Row`s of `Expanded` cells rather than a `GridView`, so a row
  can grow at large text sizes.
- **Cell**: minimum height 56, radius 8, label over total with a 2px gap,
  both centred. An `InkWell` with `borderRadius` 8.

Cell states:

| Month | Fill | Label | Total | Tappable |
| --- | --- | --- | --- | --- |
| The month on screen | `primary` | `onPrimary` | `onPrimary` | yes, closes the sheet, moves nowhere |
| Spending, not after the opened month | `surface` | `onSurface` | `onSurfaceVariant` | yes |
| Nothing spent, not after the opened month | `surface` | `onSurfaceVariant` | none | yes |
| After the opened month | none | `outline` | none | no |

A month with nothing in it stays tappable for the same reason the trend draws
empty months: the reader may want to see that nothing happened, and lands on
"Nothing in March 2026." with the trend to move on from.

Focus: the same mark `_MonthColumnState` paints, a 2px `primary` border in
`foregroundDecoration` at the cell's radius. Material's tint would not read
on these greys (measured at 1.17:1 on the header); a line in the accent does.

Year bounds: the left chevron is disabled at the year of the oldest Expense
(`expenses.last.date.year`; the Ledger is newest first), the right at the
opened month's year. A year in between with no Expenses is still reachable
and shows twelve empty cells. Disabled chevrons use the theme's disabled
colour; do not hide them, or the year label shifts.

Totals: `Rollup.trailing(expenses, year: year, month: 12, months: 12,
homeCurrency: ...)` computed by the sheet when it opens and when the year
changes. Read `homeCurrency` from `rollup.homeCurrency`. A cell prints
`asAmount(total)`, no ISO code: the code is in the header above and every
cell would repeat it. Semantics carry the code (below).

The sheet needs to know the opened month to grey out what lies past it. Add
`opened` to `LedgerReady` (year and month) rather than reading the window's
last month, which is not the same thing. The bloc already holds it.

### The pill

- Shown when `rollup` is not the opened month. Not shown otherwise, and not
  shown before `LedgerReady`.
- Position: 24px above the bottom safe inset, centred in the width left of
  the FAB column (the screen's width minus 88: the 56px FAB, its 16px inset,
  and 16px clearance). Never under the camera.
- 40px tall, radius 20, `surfaceContainer` fill, 1px `outlineVariant`
  border, elevation 3. Padding 18px left, 16px right, 8px between label and
  icon.
- Label: `ledgerBackToMonth(shortMonthAndYearLabel)` cased, in `primary`.
  Icon: `Icons.arrow_forward`, 16px, `primary`. Today is always later than
  where the reader is, so the arrow points forward; Flutter mirrors this icon
  under RTL.
- Tap: `MonthPicked(opened.year, opened.month)`.
- The list gets 88px of bottom padding so its last row and the `LeftOut`
  notice can scroll clear of the pill and the FABs. Today they cannot.

## Events and state

No new bloc events. The sheet and the pill both send the existing
`MonthPicked(year, month)`; the window rule in `_windowEndingFor` places the
trend. One state change: `LedgerReady.opened`.

## Motion

| Element | Trigger | Animation | Duration | Easing |
| --- | --- | --- | --- | --- |
| Sheet | open, close | Material's bottom sheet transition | default | default |
| Pill | appears, disappears | opacity 0→1 with an 8px rise | 200ms | `Curves.easeOutCubic` |
| Cell, badge, chevrons | pressed | ink splash | default | default |

The pill animates so that a month change does not pop chrome onto the
screen. Nothing else moves.

## Copy

Every string is a message in both ARB files under `lib/l10n/` (ADR-0007), and
`flutter gen-l10n` runs after. Upper case is applied with `cased()` at the
call site, never in the message. The house dash is `—`.

| Key | English | Where |
| --- | --- | --- |
| `ledgerChooseAMonth` | Choose a month | badge button tooltip and semantic hint |
| `ledgerPreviousYear` | Previous year | left chevron tooltip |
| `ledgerNextYear` | Next year | right chevron tooltip |
| `ledgerBackToMonth` | Back to {month} | pill label, `month` is `shortMonthAndYearLabel` |

Reuse, not new: cells announce themselves with `chartsMonthTotal`
("{month}, {amount}"), the same words the trend's columns use. Month labels
come from `Rollup.shortMonthLabel` (`DateFormat.MMM`), which is right in
Chinese where three letters are not.

## Accessibility

- Badge button: role button, label the month as `monthLabel` (the full
  name, not the cased abbreviation), hint `ledgerChooseAMonth`.
- Sheet: the year is a `Semantics(header: true)`. Focus order: previous year,
  next year, then the cells January to December. Future cells set
  `canRequestFocus: false` and `enabled: false`, so a screen reader hears
  them as dimmed and switch access skips them.
- Cells: `Semantics(button: true, excludeSemantics: true)` with the label
  `chartsMonthTotal(monthLabel, asMoney(homeCurrency, total))`. The label of
  an empty month is `monthLabel` alone.
- Pill: role button, label `ledgerBackToMonth(monthLabel)`, the full month.
- Back (Android) and Escape close the sheet with no change of month.
- Touch targets: nothing here is under 44px. The badge reaches it with
  `padded`; cells are 56; icon buttons are 48; the pill is 40 tall and gets
  `padded` too.
- Colour is never the only signal. The showing month is also named in the
  header; a future month has no total and does not respond; the pill says
  the month in words.

## Edge cases

- **Text scale 200%.** Cells grow in height (minimum, not fixed); labels may
  wrap to two lines and `maxLines: 2` with ellipsis holds them. The year row
  and the pill grow with their text. The badge's 28px becomes whatever the
  scaled label needs; the header already tolerates this for the trend.
- **Chinese.** Badge `2026年9月`, year `2026年`, cells `9月`. `cased()` is a
  no-op. Check the pill still fits beside the FAB column at zh 200%; if not,
  the label ellipsises rather than the pill growing under the camera.
- **First month of use.** One year, most cells empty, the left chevron
  disabled at once. Still fine.
- **No home currency yet** (`LedgerWithoutHomeCurrency`). No header, so no
  badge, no sheet, no pill. Unchanged from today.
- **The showing month's cell.** Tapping it closes the sheet; nothing is
  sent.
- **Rapid taps.** `MonthPicked` is idempotent and the sheet pops once.
- **Small phones in landscape.** The sheet scrolls; it does not clip.
- **Tablet.** `showModalBottomSheet` caps width at 640 by default. Keep it.

## Not in scope

- Day-level navigation. The Ledger, its Rollup and its trend are all
  month-grained; "specific dates" was read as months. If a day view is
  wanted, it is a separate spec.
- Swiping between months (Option D's gesture). Only its pill was kept.
- Changing the trend or its window rule.

## Tests to write first

In the style of `test/ledger/month_on_screen_test.dart`; its `column()` helper is the
model for telling a cased abbreviation from a sentence naming the same month.

- Tapping the badge opens the sheet showing the on-screen month's year.
- Tapping a past month's cell emits `MonthPicked` for it and closes the sheet.
- Months after the opened month are not tappable and have no total.
- The chevrons stop at the oldest Expense's year and the opened year.
- The pill is absent on the opened month, present after `MonthPicked` moved
  away, and its tap returns to the opened month.
- The pill is absent in `LedgerWithoutHomeCurrency`.
- Chinese labels: `9月` in a cell, `2026年` in the year row, no upper-casing.
- At `textScaler` 2.0 nothing overflows on a 390×844 surface.
- Every new key exists in both ARB files (`what_the_domain_is_called_test`
  is the pattern for a key the message files forgot).

## Checks before calling it done

`flutter analyze` clean, `flutter test` green, then the `run` skill on the
device: every visual finding on this screen so far came from the phone, not
the suite. Look at the pill beside the camera, the sheet on the opened
month, and the focus ring under switch access.
