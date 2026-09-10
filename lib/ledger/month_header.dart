/// What the month on screen came to, above the list it is the total of.
///
/// Direction C folds the figure, the comparison and the trend into the
/// Ledger's own header rather than keeping them a tap away on the chart
/// detail, so the first thing the screen says is what the month cost. Every
/// value is read off the Rollup the bloc already computed; nothing here is
/// worked out twice.
library;

import 'package:flutter/material.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../settings/themes.dart';
import 'charts.dart';

/// Short enough to sit above a list and still leave it most of the screen.
const double _trendHeight = 40;

class MonthHeader extends StatelessWidget {
  const MonthHeader(
    this.rollup,
    this.trend, {
    required this.onMonthPicked,
    required this.onChooseMonth,
    super.key,
  });

  final Rollup rollup;

  /// The months around [rollup], oldest first and including it.
  final List<Rollup> trend;

  final void Function(Rollup month) onMonthPicked;

  /// The badge tapped: the reader wants to name a month rather than step to
  /// one. What that opens is the screen's business, not this header's.
  final VoidCallback onChooseMonth;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colours.surfaceContainer,
        border: Border(bottom: BorderSide(color: colours.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: _Total(rollup)),
                _Badge(rollup, onTap: onChooseMonth),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rollup.comparedWithPreviousMonth(words),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 13),
            // Drawn even when every month in it is empty, unlike the chart
            // detail's copy of the same trend. There it is a picture and a
            // flat one is worth hiding; here it is the only way through the
            // months, and hiding it strands the reader on a month with
            // nothing in it and no way off.
            MonthColumns(
              trend,
              showing: rollup,
              height: _trendHeight,
              onPicked: onMonthPicked,
            ),
          ],
        ),
      ),
    );
  }
}

/// The month on screen, and the way to any other. A label until the trend
/// below it turned out to be the only route through the months, and a route
/// six months wide is no route to last year.
///
/// The chevron is drawn on every month, the one the app opened in included, so
/// the way in looks the same wherever the reader has got to.
class _Badge extends StatelessWidget {
  const _Badge(this.rollup, {required this.onTap});

  final Rollup rollup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return Tooltip(
      message: words.ledgerChooseAMonth,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: colours.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          // Material's own 64px floor would put the badge miles off the right
          // edge; the shape is the label plus its padding.
          minimumSize: Size.zero,
          // A 28px badge is not a target. This is the only thing on the
          // screen that costs the header height, and it buys the one control
          // that reaches a month the trend cannot.
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        // Inside the button rather than around it: excluding the subtree from
        // above would take the focus node with it, which is the defect
        // `charts.dart` records against the trend's columns.
        child: Semantics(
          // The month spelled out, not the cased abbreviation the badge
          // draws, and the hint says what tapping it does.
          label: rollup.monthLabel(words),
          hint: words.ledgerChooseAMonth,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cased(words, rollup.shortMonthAndYearLabel(words)),
                style: atItsWeight(
                  theme.textTheme.labelSmall?.copyWith(
                    color: colours.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// The month's total, with the ISO code kept on the figure rather than split
/// off it. The rows below do split it, because a column of amounts is read
/// down and the codes repeat; a headline is read once.
class _Total extends StatelessWidget {
  const _Total(this.rollup);

  final Rollup rollup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      asMoney(rollup.homeCurrency, rollup.total),
      style: asClaimedFigure(theme.textTheme.titleLarge),
    );
  }
}
