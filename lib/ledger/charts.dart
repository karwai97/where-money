/// The two charts a month reduces to. Both draw a single series in one hue
/// taken from the theme, so they follow light and dark rather than carrying
/// colours of their own, and both read magnitude by length — the one channel
/// that survives a colourblind reader, a grayscale print and a phone in the
/// sun. Nothing is said in colour alone: the breakdown prints every row's
/// amount, the trend prints the month it is showing, and the rest of the
/// trend's numbers are on the bars for a screen reader.
library;

import 'package:flutter/material.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';

const double _barThickness = 10;
const double _columnWidth = 20;
const double _plotHeight = 140;

/// What each Category cost this month, biggest first.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown(this.rollup, {super.key});

  final Rollup rollup;

  @override
  Widget build(BuildContext context) {
    if (rollup.byCategory.isEmpty) return const SizedBox.shrink();

    final words = AppLocalizations.of(context);
    final colours = Theme.of(context).colorScheme;
    final largest = rollup.byCategory.first.amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in rollup.byCategory)
          Semantics(
            label: words.chartsCategoryTotal(
              category.labelIn(words),
              asMoney(rollup.homeCurrency, category.amount),
              category.count,
            ),
            // Its own node, or the rows merge and a screen reader reads the
            // whole column as one utterance with no way to step through it.
            container: true,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category.labelIn(words))),
                      Text(asMoney(rollup.homeCurrency, category.amount)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _Track(
                    label: category.labelIn(words),
                    fraction: category.amount / largest,
                    fill: colours.primary,
                    track: colours.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.label,
    required this.fraction,
    required this.fill,
    required this.track,
  });

  final String label;
  final double fraction;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(_barThickness / 2),
    child: Container(
      height: _barThickness,
      color: track,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        // A category that cost almost nothing still gets a mark, so a row with
        // a number beside it is never a row with nothing beside it.
        widthFactor: fraction.clamp(0.02, 1.0),
        // The height has to be asked for. Aligning inside the track leaves the
        // fill loosely constrained, and a DecoratedBox with no child of its own
        // answers that by taking no height at all — which drew every bar
        // invisible while every number beside it stayed right.
        heightFactor: 1,
        child: DecoratedBox(
          key: ValueKey('category bar: $label'),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(_barThickness / 2),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The months leading up to this one, so a total has a direction to be read
/// against. The month on screen is the only one in the accent colour: the
/// others are context, and colouring them all would bury the point.
class MonthTrend extends StatelessWidget {
  const MonthTrend(this.months, {super.key});

  final List<Rollup> months;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final showing = months.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The one month the reader came for gets its number; a number on every
        // bar would be read by nobody.
        Text(
          asMoney(showing.homeCurrency, showing.total),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(height: _plotHeight, child: _Columns(months, showing)),
      ],
    );
  }
}

class _Columns extends StatelessWidget {
  const _Columns(this.months, this.showing);

  final List<Rollup> months;
  final Rollup showing;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tallest = months.map((r) => r.total).reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final month in months)
          Expanded(
            child: Semantics(
              label: words.chartsMonthTotal(
                month.monthLabel(words),
                asMoney(month.homeCurrency, month.total),
              ),
              container: true,
              excludeSemantics: true,
              child: Column(
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: tallest == 0
                          ? 0
                          : (month.total / tallest).clamp(0.0, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: _columnWidth,
                          decoration: BoxDecoration(
                            color:
                                month.year == showing.year &&
                                    month.month == showing.month
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    month.shortMonthLabel(words),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
