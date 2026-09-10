/// Naming a month and going to it. The trend above the Ledger's list moves one
/// month per tap and is six months wide, so anything older than the window
/// meant tapping the edge column and waiting for the window to slide. This is
/// a year at a time: twelve months, each with what it cost, and any of them
/// two taps away.
///
/// Every total here is a Rollup, computed the same way the trend's bars and
/// the chart detail's breakdown are, so a cell and the month it opens cannot
/// disagree.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../settings/themes.dart';

/// The cell's corner, and the ring drawn at it.
const double _cellRadius = 8;

/// A minimum rather than a fixed height: at large text sizes a month label
/// wraps and the cell grows instead of clipping.
const double _cellHeight = 56;

const double _cellGap = 8;

/// The least room the year is given, so the two chevrons either side of it do
/// not close in on a shorter one. A floor rather than a width: `2026年` and a
/// scaled-up label both need more.
const double _yearWidth = 64;

/// A month picked from the sheet, or null if the reader closed it without one
/// — including by tapping the month they were already on.
Future<DateTime?> chooseAMonth(
  BuildContext context, {
  required List<Expense> expenses,
  required Rollup showing,
  required DateTime opened,
}) => showModalBottomSheet<DateTime>(
  context: context,
  // The default 9/16 height cap clips a grid of twelve on a small phone in
  // landscape, and [_AYearOfMonths] scrolls rather than shrinking.
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
  builder: (context) =>
      _AYearOfMonths(expenses: expenses, showing: showing, opened: opened),
);

class _AYearOfMonths extends StatefulWidget {
  const _AYearOfMonths({
    required this.expenses,
    required this.showing,
    required this.opened,
  });

  /// The whole Ledger, newest first, which is what the twelve totals are
  /// computed from.
  final List<Expense> expenses;

  final Rollup showing;

  /// The month the app was opened in. Nothing after it is reachable.
  final DateTime opened;

  @override
  State<_AYearOfMonths> createState() => _AYearOfMonthsState();
}

class _AYearOfMonthsState extends State<_AYearOfMonths> {
  late int _year;

  /// January to December of [_year]. Held rather than computed in [build]:
  /// twelve Rollups over the whole Ledger is the one expensive thing here, and
  /// it is only worth paying for when the year moves.
  late List<Rollup> _months;

  @override
  void initState() {
    super.initState();
    _year = widget.showing.year;
    _months = _monthsOf(_year);
  }

  /// The year of the oldest Expense, which is the last of a Ledger held newest
  /// first — or the year the reader is already on, whichever is further back.
  /// The trend's window reaches past the oldest Expense, so a reader who
  /// walked down it can be standing in a year that has never been spent in,
  /// and a sheet that refused to open on the month it was opened from would be
  /// the one place they could not get back to.
  int get _oldest => math.min(
    widget.showing.year,
    widget.expenses.isEmpty ? _newest : widget.expenses.last.date.year,
  );

  int get _newest => widget.opened.year;

  List<Rollup> _monthsOf(int year) => Rollup.trailing(
    widget.expenses,
    year: year,
    month: 12,
    months: 12,
    homeCurrency: widget.showing.homeCurrency,
  );

  void _goTo(int year) => setState(() {
    _year = year;
    _months = _monthsOf(year);
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      // `useSafeArea` is `SafeArea(bottom: false)` for a modal sheet — the
      // shape is meant to run to the edge of the screen and the content is
      // meant to hold itself off it — so the inset is added here or the
      // bottom row of cells sits under the gesture bar.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 28 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _YearRow(
            year: _year,
            onPrevious: _year > _oldest ? () => _goTo(_year - 1) : null,
            onNext: _year < _newest ? () => _goTo(_year + 1) : null,
          ),
          const SizedBox(height: 12),
          for (var row = 0; row < 4; row++) ...[
            if (row > 0) const SizedBox(height: _cellGap),
            // Rows of Expanded cells rather than a GridView, so a row can
            // grow when its labels wrap at large text sizes. IntrinsicHeight
            // is what lets the three cells in a row match the tallest of
            // them; three children is a price worth paying for that.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < 3; column++) ...[
                    if (column > 0) const SizedBox(width: _cellGap),
                    Expanded(child: _cell(row * 3 + column)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _cell(int index) {
    final month = _months[index];
    final at = DateTime(month.year, month.month);
    final isShowing =
        month.year == widget.showing.year &&
        month.month == widget.showing.month;

    return _MonthCell(
      month,
      isShowing: isShowing,
      isAhead: at.isAfter(widget.opened),
      // The month already on screen is tappable and sends nothing: closing
      // the sheet is the whole of what the tap meant, and moving to a month
      // the reader is already on is a state change nobody asked for.
      onTap: () => Navigator.of(context).pop(isShowing ? null : at),
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({
    required this.year,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;

  /// Null at the end of the Ledger in that direction. Disabled rather than
  /// gone: a chevron that disappears takes the year label sideways with it.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: words.ledgerPreviousYear,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        // What the grid under it is a year of, which is a heading rather than
        // a label on the chevrons either side.
        Semantics(
          header: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _yearWidth),
            child: Text(
              asYear(words, DateTime(year)),
              textAlign: TextAlign.center,
              style: asFigures(theme.textTheme.titleSmall),
            ),
          ),
        ),
        IconButton(
          tooltip: words.ledgerNextYear,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// One month of the year, with what it cost under its name.
class _MonthCell extends StatefulWidget {
  const _MonthCell(
    this.month, {
    required this.isShowing,
    required this.isAhead,
    required this.onTap,
  });

  final Rollup month;

  /// Whether this is the month the Ledger is on, which is the one filled cell.
  final bool isShowing;

  /// Whether this month lies after the one the app was opened in. There is
  /// nothing to see there, so it carries no total and does not respond.
  final bool isAhead;

  final VoidCallback onTap;

  @override
  State<_MonthCell> createState() => _MonthCellState();
}

class _MonthCellState extends State<_MonthCell> {
  /// Held because the ring is drawn rather than washed on, for the reason
  /// `_MonthColumnState` in `charts.dart` gives: Material's tint over these
  /// greys measures 1.17:1 and is no mark at all.
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    // A month with nothing in it is still somewhere to go — the reader may
    // want to see that nothing happened — so it keeps its cell and loses only
    // its figure.
    final totalled = month.hasSpending && !widget.isAhead;
    // Both halves off one reading of the cell's state. Branched twice they
    // could disagree, and ink on a fill it was not measured against is the
    // one way this table goes wrong without looking wrong.
    final (Color fill, Color ink) = switch (widget) {
      _MonthCell(isShowing: true) => (colours.primary, colours.onPrimary),
      _MonthCell(isAhead: true) => (Colors.transparent, colours.outline),
      _ when totalled => (colours.surface, colours.onSurface),
      _ => (colours.surface, colours.onSurfaceVariant),
    };

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(_cellRadius),
      // The InkWell is the outer one and the label is published inside it, as
      // the trend's columns do it: a Semantics that excluded the whole subtree
      // would take the focus node with it.
      child: InkWell(
        onTap: widget.isAhead ? null : widget.onTap,
        canRequestFocus: !widget.isAhead,
        borderRadius: BorderRadius.circular(_cellRadius),
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Semantics(
          button: true,
          enabled: !widget.isAhead,
          label: totalled
              ? words.chartsMonthTotal(
                  month.monthLabel(words),
                  asMoney(month.homeCurrency, month.total),
                )
              : month.monthLabel(words),
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: _cellHeight),
            // In front of the cell rather than around it, so nothing shifts
            // when focus arrives.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_cellRadius),
              border: Border.all(
                color: _focused ? colours.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cased(words, month.shortMonthLabel(words)),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: asTrackedMark(
                    theme.textTheme.labelSmall?.copyWith(color: ink),
                  ),
                ),
                if (totalled) ...[
                  const SizedBox(height: 2),
                  Text(
                    // No ISO code: it is in the header above, and twelve
                    // cells would each repeat it. The screen reader's label
                    // carries it.
                    asAmount(month.total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: asFigures(
                      theme.textTheme.bodySmall?.copyWith(
                        color: widget.isShowing
                            ? colours.onPrimary
                            : colours.onSurfaceVariant,
                        // Asked for as well as the monospaced face, which
                        // does not need it: until that face is fetched this
                        // draws in the fallback, and three figures across a
                        // row should line up on their digits.
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
