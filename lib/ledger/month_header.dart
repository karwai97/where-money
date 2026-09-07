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
import 'charts.dart';

/// Short enough to sit above a list and still leave it most of the screen.
const double _trendHeight = 40;

class MonthHeader extends StatelessWidget {
  const MonthHeader(
    this.rollup,
    this.trend, {
    required this.onMonthPicked,
    super.key,
  });

  final Rollup rollup;

  /// The months around [rollup], oldest first and including it.
  final List<Rollup> trend;

  final void Function(Rollup month) onMonthPicked;

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
                Text(
                  rollup.shortMonthAndYearLabel(words),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colours.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
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
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        // The one thing the figures owe each other across a month change: the
        // total must not jog sideways when 1284.60 becomes 998.00.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
