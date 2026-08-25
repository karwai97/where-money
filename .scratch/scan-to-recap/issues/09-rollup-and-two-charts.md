# 09 — Rollup and two charts

**What to build:** A user picks a month and sees where the money went: a breakdown
by Category, and how this month compares to last. If any Expenses were left out
because they were paid in another currency, the app says how many rather than
quietly producing a total that doesn't reconcile.

Two charts, not a dashboard. The breakdown answers "what did I spend on", the
month-over-month trend answers "is this getting worse", and the trend is nearly
free because the Rollup already computes those deltas for the Recap to use. The
trend is also what makes the Recap checkable later — read that dining went up 40%,
then look at the chart and see it.

The Rollup is computed on device in pure Dart and is never written to Firestore.
One truth, and it stays deterministic and testable.

**Blocked by:** 02, 03

**Status:** ready-for-agent

- [x] The Ledger can be filtered to a month
- [x] A category breakdown for the selected month
- [x] A month-over-month trend covering enough months to show a direction
- [x] Expenses outside the Home Currency are excluded from both charts, and the excluded count is on screen
- [x] A month with no Expenses renders as empty rather than as an error or a zeroed chart
- [x] Nothing derived from the Rollup is persisted
- [x] Charts are legible in both light and dark themes

## Comments

Implemented. Six of seven criteria are ticked and each is covered by a test.
**Criterion 7 is deliberately left unticked**: the app now has a dark theme and
both charts take every colour from the scheme, but nobody has looked at them.
Legibility is a claim about eyes, and there is still no Android device on this
machine — four tickets of unwatched work are now stacked up.

### Two charts, no chart library

`fl_chart` and its neighbours were not added. Both charts are ordinary widgets:
the breakdown is a row per Category with the amount printed beside it and a
proportional bar under it, and the trend is six columns with the month on
screen in the accent colour and the others in the recessive one. Each carries
its numbers as text and as a screen-reader label, so nothing is said in colour
alone and neither chart needs a legend. That also means no new dependency, no
licence, and no third thing to fake.

The one distortion worth naming: a Category that cost almost nothing still gets
a two-percent bar, so a row with a number beside it is never a row with nothing
beside it. It makes the smallest bars read as more alike than they are. The
amount is printed on every row, which is where the truth is.

### The trend is a list of Rollups

`Rollup.trailing` is the only new maths, and it is thin on purpose — it calls
`Rollup.forMonth` once per month. The bar a month shows and the breakdown that
month opens into are therefore the same arithmetic, which is what will let the
Recap be checked against the picture in ticket 10. A month nobody spent
anything in comes back as an empty Rollup rather than being skipped, so a gap
in the Ledger reads as a gap.

Six months. Fewer does not show a direction; more turns the bars into a stripe
on a phone.

### The Home Currency exclusion is said twice, because it is true twice

Review caught this and it was a real gap: the note only qualified the month on
screen, so last month's SGD Expense was dropped from its bar in the trend with
nothing on screen about it. Every chart that leaves something out now says so
under itself, the trend counting across all six months it draws. `_LeftOut`
renders nothing when there is nothing to declare.

### Deliberate additions the ticket did not ask for

Declared rather than smuggled, as ticket 04 did.

- **A total and a comparison above the charts** — "MYR 1806.75", then "43% more
  than July 2026". It is the delta the Rollup already computes, printed rather
  than left for the reader to eyeball. It is not a Recap: no model is called
  and nothing is generated. Ticket 10 owns the words.
- **Forward navigation stops at the month the app opened in.** There is nothing
  to see after today, and a chevron leading to a run of empty months is a
  chevron that lies. Backwards is unbounded on purpose — a Ledger can have gaps
  and a user is allowed to look into them.
- **A dark theme**, which criterion 7 cannot be judged without. It is one line
  and the default Material scheme for a dark surface; the seed colour an
  earlier draft added was an app-wide restyle this ticket has no business doing
  and was taken back out in review.
- **`asMoney` and `asExpenses`** in `on_screen.dart`, beside the date helpers,
  because money and a count of Expenses were being formatted in three places.

### What is proved by test, and what is not

Twenty-four tests in `test/ledger/`, plus seven in `packages/core`. The month
filter, the breakdown's numbers, the trend's six months, the exclusion note on
both charts, the empty month and "nothing is persisted" are all asserted on
numbers or on text the user can read.

Two things are weaker than they look:

- **The dark-theme test only proves the values are still printed.** It would
  pass if every bar rendered invisible. It is named for what it checks rather
  than for what the criterion wants, which is why the criterion is unticked.
- **Nothing asserts which bar is accented.** That is a colour in the tree, and
  this repo does not assert on trees. It is checked by reading the code.

### Left undone, on purpose

- **The Home Currency is a constant**, `homeCurrency` in `ledger_bloc.dart`.
  There is no settings screen and this ticket is not the place to invent one.
  A first draft made it a bloc parameter no caller ever set; review called that
  what it was and it went.
- **A `Month` value type** was argued for in review — the month on screen is a
  `DateTime` pinned to the first, then taken apart into `year:`/`month:` at
  every call. It would be better. It is also a word `CONTEXT.md` does not have,
  and de-duplicating the month filter (`expensesIn`) and the label took most of
  the pressure off. Left for whoever needs it.
- **The Ledger list still shows the raw Category slug** — "dining" where the
  chart says "Dining out". Pre-existing, one line to fix, and not this ticket's.
- **The charts cannot change month.** The month is picked on the Ledger and the
  charts follow it; the screen's title names the month so nothing is ambiguous.
- **`packages/core/lib/src/rollup.dart` carries two hunks of pure formatter
  churn** from this machine's `dart format`, as the handoff warned.

### Measured on a device, 2026-08-25, and it found a bug

This criterion was deliberately left unticked because contrast had been reasoned
about rather than looked at. Looking at it on the OPPO CPH2499 found that
**the category bars were not being drawn at all** — every row showed its empty
track, in both themes, while the Category name and the amount beside it read
perfectly.

The cause was geometry, not colour. `_Track` aligns the fill inside a
fixed-height container, which leaves the fill loosely constrained, and a
`DecoratedBox` with no child of its own answers a loose height constraint by
taking no height. `heightFactor: 1` fixes it. `month_on_screen_test.dart` now
pins it, and unusually for this repo the assertion is geometric — the defect was
geometric, and every assertion on visible text passed throughout.

With that fixed, both charts read clearly in both themes: the accent bars carry
against either surface and every label and figure is high contrast.

**What was not measured**: one Category. Relative bar lengths across a full
month, and the 2% floor a nearly-free Category is clamped to, have still only
been reasoned about.
